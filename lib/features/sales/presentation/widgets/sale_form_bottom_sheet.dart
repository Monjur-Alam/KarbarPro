import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../customers/domain/customer.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../inventory/domain/product.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../domain/sale.dart';
import '../bloc/sales_bloc.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/invoice_service.dart';

class SaleFormBottomSheet extends StatefulWidget {
  const SaleFormBottomSheet({super.key});

  @override
  State<SaleFormBottomSheet> createState() => _SaleFormBottomSheetState();
}

class _SaleFormBottomSheetState extends State<SaleFormBottomSheet> {
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  final FocusNode _discountFocus = FocusNode();
  final FocusNode _paidAmountFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();

  bool _isPartialPayment = false;

  late final MobileScannerController _scannerController;
  bool _cameraPermissionGranted = false;
  String? _scanFeedback; // null = hidden; product name = success; '' = not found
  bool _scanSuccess = false;
  Timer? _feedbackTimer;
  final Map<String, DateTime> _lastScanTime = {};

  Sale? _completedSale;
  String? _beepFilePath;

  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(ClearCart());
    _scannerController = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    _requestCameraPermission();
    _initBeepFile();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) setState(() => _cameraPermissionGranted = status.isGranted);
  }

  @override
  void dispose() {
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    _discountFocus.dispose();
    _paidAmountFocus.dispose();
    _notesFocus.dispose();
    _scannerController.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _onBarcodeScanned(BarcodeCapture capture, List<Product> products) {
    final code = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    // Per-code cooldown: ignore if same code scanned within 1.5 seconds
    final now = DateTime.now();
    final last = _lastScanTime[code];
    if (last != null && now.difference(last) < const Duration(milliseconds: 1500)) return;
    _lastScanTime[code] = now;

    final product = products.where((p) => p.barcode?.trim() == code).firstOrNull;

    if (product == null) {
      HapticFeedback.heavyImpact();
      _showScanFeedback('', false);
    } else if (product.currentStock <= 0) {
      HapticFeedback.heavyImpact();
      _showScanFeedback(product.name, false);
    } else {
      context.read<SalesBloc>().add(AddToCart(product));
      _playBeep();
      HapticFeedback.mediumImpact();
      _showScanFeedback(product.name, true);
    }
  }

  void _showScanFeedback(String productName, bool success) {
    _feedbackTimer?.cancel();
    setState(() {
      _scanFeedback = productName;
      _scanSuccess = success;
    });
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _scanFeedback = null);
    });
  }

  Future<void> _initBeepFile() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/scan_beep.wav');
      if (!file.existsSync()) {
        file.writeAsBytesSync(_generateBeepWav());
      }
      if (mounted) _beepFilePath = file.path;
    } catch (_) {}
  }

  Future<void> _playBeep() async {
    if (_beepFilePath == null) return;
    try {
      // Fresh player each time so rapid scans never interrupt each other
      final player = AudioPlayer();
      await player.play(DeviceFileSource(_beepFilePath!));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {}
  }

  Uint8List _generateBeepWav() {
    const sampleRate = 22050;
    const frequency = 880;
    // 60ms silence lets Android audio output initialise before tone starts
    const silenceSamples = sampleRate * 60 ~/ 1000;
    // 220ms tone — long enough to hear clearly on all devices
    const toneSamples = sampleRate * 220 ~/ 1000;
    const numSamples = silenceSamples + toneSamples;
    const amplitude = 0.65;

    final pcm = Int16List(numSamples); // zeros = silence for first silenceSamples
    for (int i = 0; i < toneSamples; i++) {
      final t = i / sampleRate;
      // Smooth attack (first 8%) and release (last 15%) to avoid clicks
      double env = 1.0;
      if (i < toneSamples * 0.08) {
        env = i / (toneSamples * 0.08);
      } else if (i > toneSamples * 0.85) {
        env = (toneSamples - i) / (toneSamples * 0.15);
      }
      final sample = (sin(2 * pi * frequency * t) * amplitude * 32767 * env).round();
      pcm[silenceSamples + i] = sample.clamp(-32768, 32767);
    }

    final dataSize = numSamples * 2;
    final bd = ByteData(44 + dataSize);
    // RIFF chunk
    [0x52, 0x49, 0x46, 0x46].asMap().forEach((i, v) => bd.setUint8(i, v));
    bd.setUint32(4, 36 + dataSize, Endian.little);
    [0x57, 0x41, 0x56, 0x45].asMap().forEach((i, v) => bd.setUint8(8 + i, v));
    // fmt chunk
    [0x66, 0x6D, 0x74, 0x20].asMap().forEach((i, v) => bd.setUint8(12 + i, v));
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    // data chunk
    [0x64, 0x61, 0x74, 0x61].asMap().forEach((i, v) => bd.setUint8(36 + i, v));
    bd.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < numSamples; i++) {
      bd.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return bd.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          HapticFeedback.heavyImpact();
          setState(() => _completedSale = state.sale);
        } else if (state is SalesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: colorScheme.error),
          );
        }
      },
      builder: (context, state) {
        if (state is! SalesDataLoaded) return const Center(child: CircularProgressIndicator());

        double subTotal = state.totalAmount;
        double discount = double.tryParse(_discountController.text) ?? 0;
        double finalTotal = subTotal - discount;
        if (finalTotal < 0) finalTotal = 0;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 16).copyWith(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      children: [
                        const SizedBox(height: 12),
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _completedSale != null ? '✅ ${l10n.saleSuccess}' : l10n.newSaleInvoice,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _completedSale != null ? Colors.green.shade700 : colorScheme.onSurface,
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 16),

                        if (_completedSale != null) ...[
                          _buildSuccessCard(_completedSale!),
                        ] else ...[
                          // Product Selection Section
                          _buildSectionHeader('📦 ${l10n.selectProduct}', colorScheme.primary),
                          const SizedBox(height: 12),
                          _buildProductSelector(),
                          const SizedBox(height: 12),
                          _buildScannerBox(),

                          // Cart Summary Section
                          if (state.cart.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildSectionHeader('🛒 ${l10n.cartListCount(l10n.formatDigits(state.cart.length.toString()))}', colorScheme.tertiary),
                            const SizedBox(height: 8),
                            _buildCartList(state),
                          ],

                          // Payment Section
                          const SizedBox(height: 24),
                          _buildSectionHeader('💳 ${l10n.paymentInfo}', Colors.green),
                          const SizedBox(height: 12),
                          _buildPaymentTypeToggle(state),

                          const SizedBox(height: 16),
                          if (state.paymentType == PaymentType.credit) ...[
                            _buildCustomerSelector(state.selectedCustomer),
                            const SizedBox(height: 16),
                            _buildPartialPaymentSection(finalTotal),
                          ] else ...[
                            _buildTextField(_discountController, l10n.discountTaka, prefix: '৳', isNumber: true, onChanged: (_) => setState(() {}), focusNode: _discountFocus, textInputAction: TextInputAction.next, nextFocus: _notesFocus),
                          ],

                          const SizedBox(height: 16),
                          _buildTextField(_notesController, '💬 ${l10n.additionalNotes}', maxLines: 2, focusNode: _notesFocus),

                          const SizedBox(height: 32),
                          _buildCheckoutSummary(state, finalTotal),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // Sticky bottom buttons
                  _buildStickyBottomBar(context, state, finalTotal, l10n, colorScheme),
                ],
              ),
            );
          },
        ),
        );
      },
    );
  }

  Widget _buildSuccessCard(Sale sale) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg     = isDark ? Colors.green.shade900.withValues(alpha: 0.25) : Colors.green.shade50;
    final cardBorder = isDark ? Colors.green.shade700 : Colors.green.shade200;
    final titleColor = isDark ? Colors.green.shade300 : Colors.green.shade800;
    final hintColor  = isDark ? Colors.green.shade400 : Colors.green.shade600;
    final dueColor   = isDark ? Colors.red.shade300   : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: titleColor, size: 56),
          const SizedBox(height: 12),
          Text(l10n.saleSuccess, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 16),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 8),
          _infoRow(l10n.invoiceColon, l10n.formatDigits(sale.invoiceId), colorScheme),
          _infoRow(l10n.totalAmountLabel, '৳${l10n.formatAmount(sale.totalAmount)}', colorScheme),
          _infoRow(l10n.payment, sale.paymentMethod == 'cash' ? l10n.cash : l10n.credit, colorScheme),
          if (sale.dueAmount > 0)
            _infoRow(l10n.due, '৳${l10n.formatAmount(sale.dueAmount)}', colorScheme, valueColor: dueColor),
          const SizedBox(height: 8),
          Text(
            l10n.isBangla
                ? 'আবার বিক্রয় করতে বন্ধ করে নতুন বিক্রয় শুরু করুন'
                : 'Close and start a new sale',
            style: TextStyle(fontSize: 11, color: hintColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? cs.onSurface)),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(
    BuildContext context,
    SalesDataLoaded state,
    double finalTotal,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: _completedSale != null
          ? _buildSuccessButtons(l10n)
          : _buildCartButtons(state, finalTotal, l10n),
    );
  }

  Widget _buildCartButtons(SalesDataLoaded state, double finalTotal, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.cancel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: state.isSubmitting || state.cart.isEmpty ? null : () => _handleCheckout(state, finalTotal),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: state.isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(l10n.completeSale, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  bool _isSharingReceipt  = false;
  bool _isPrintingReceipt = false;

  Widget _buildSuccessButtons(AppLocalizations l10n) {
    return Row(
      children: [
        // ── Share ──────────────────────────────────────────────────
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSharingReceipt
                ? null
                : () async {
                    setState(() => _isSharingReceipt = true);
                    try {
                      await InvoiceService.shareReceipt(
                        _completedSale!,
                        isBangla: context.l10n.isBangla,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('শেয়ার করা যায়নি: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _isSharingReceipt = false);
                    }
                  },
            icon: _isSharingReceipt
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
                : const Icon(Icons.share_outlined, size: 18, color: Colors.teal),
            label: Text(l10n.shareReceipt, style: const TextStyle(color: Colors.teal)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.teal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ── Print ──────────────────────────────────────────────────
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isPrintingReceipt
                ? null
                : () async {
                    setState(() => _isPrintingReceipt = true);
                    try {
                      await InvoiceService.printReceipt(
                        _completedSale!,
                        isBangla: context.l10n.isBangla,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('প্রিন্ট করা যায়নি: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _isPrintingReceipt = false);
                    }
                  },
            icon: _isPrintingReceipt
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.print_outlined, size: 18),
            label: Text(l10n.printReceipt),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildCartList(SalesDataLoaded state) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.cart.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final item = state.cart[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.name, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '৳${context.l10n.formatAmount(item.product.sellingPrice)} / ${item.product.unit}',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                          if (item.product.size != null && item.product.size!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                              child: Text(item.product.size!, style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSmallQtyBtn(Icons.remove, () {
                      if (item.quantity <= 1) {
                        context.read<SalesBloc>().add(RemoveFromCart(item.product.id!));
                      } else {
                        context.read<SalesBloc>().add(UpdateCartQuantity(item.product.id!, item.quantity - 1));
                      }
                      HapticFeedback.lightImpact();
                    }, color: item.quantity <= 1 ? colorScheme.error : null),
                    Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: Text(
                        context.l10n.formatDigits(item.quantity.toString()),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface),
                      ),
                    ),
                    _buildSmallQtyBtn(Icons.add, () {
                      context.read<SalesBloc>().add(UpdateCartQuantity(item.product.id!, item.quantity + 1));
                      HapticFeedback.lightImpact();
                    }),
                    const SizedBox(width: 10),
                    Text(
                      '৳${context.l10n.formatAmount(item.subTotal)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.primary),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPartialPaymentSection(double finalTotal) {
    final l10n = context.l10n;
    return Column(
      children: [
        CheckboxListTile(
          value: _isPartialPayment,
          onChanged: (v) => setState(() {
            _isPartialPayment = v ?? false;
            if (!_isPartialPayment) _paidAmountController.text = '0';
          }),
          title: Text(l10n.cashCollectedQuestion, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        if (_isPartialPayment)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildTextField(_paidAmountController, l10n.collectedAmount, prefix: '৳', isNumber: true, onChanged: (_) => setState(() {}), focusNode: _paidAmountFocus, textInputAction: TextInputAction.next, nextFocus: _discountFocus)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_discountController, l10n.discount, prefix: '৳', isNumber: true, onChanged: (_) => setState(() {}), focusNode: _discountFocus, textInputAction: TextInputAction.next, nextFocus: _notesFocus)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCheckoutSummary(SalesDataLoaded state, double finalTotal) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    double paid = double.tryParse(_paidAmountController.text) ?? 0;
    if (state.paymentType == PaymentType.cash) paid = finalTotal;

    double due = finalTotal - paid;
    if (due < 0) due = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildSummaryRow(l10n.subTotal, '৳${l10n.formatAmount(state.totalAmount)}', colorScheme.onSurface.withOpacity(0.7)),
          _buildSummaryRow('${l10n.discount}:', '- ৳${l10n.formatAmount(double.tryParse(_discountController.text) ?? 0)}', Colors.red.shade300),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: colorScheme.onSurface.withOpacity(0.24))),
          _buildSummaryRow(l10n.grandTotal, '৳${l10n.formatAmount(finalTotal)}', colorScheme.onSurface, isBold: true, fontSize: 20),
          if (state.paymentType == PaymentType.credit) ...[
             const SizedBox(height: 8),
             _buildSummaryRow(l10n.collectedColon, '৳${l10n.formatAmount(paid)}', Colors.green.shade300),
             _buildSummaryRow(l10n.dueRemaining, '৳${l10n.formatAmount(due)}', Colors.orange.shade300),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildSmallQtyBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = color ?? colorScheme.onPrimaryContainer;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16, color: iconColor),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  void _handleCheckout(SalesDataLoaded state, double finalTotal) {
    final l10n = context.l10n;
    if (state.paymentType == PaymentType.credit && state.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectCustomerWarning), backgroundColor: Colors.orange));
      return;
    }

    double paid = double.tryParse(_paidAmountController.text) ?? 0;
    if (state.paymentType == PaymentType.cash) paid = finalTotal;

    context.read<SalesBloc>().add(CheckoutSale(
      discount: double.tryParse(_discountController.text) ?? 0,
      paidAmount: paid,
      notes: _notesController.text,
    ));
  }

  Widget _buildTextField(TextEditingController controller, String label, {String? prefix, String? suffix, bool isNumber = false, int maxLines = 1, TextAlign textAlign = TextAlign.start, Function(String)? onChanged, FocusNode? focusNode, TextInputAction? textInputAction, FocusNode? nextFocus}) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction ?? TextInputAction.done,
      onSubmitted: nextFocus != null ? (_) => nextFocus.requestFocus() : null,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      textAlign: textAlign,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildScannerBox() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, inventoryState) {
        final products = inventoryState is InventoryLoaded
            ? inventoryState.products
            : <Product>[];
        return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: _cameraPermissionGranted
            ? Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) => _onBarcodeScanned(capture, products),
                  ),
                  // Scan frame guide
                  Center(
                    child: Container(
                      width: 200,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // Label overlay
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_scanner, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(l10n.scanBarcode, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Feedback banner
                  if (_scanFeedback != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                        color: (_scanSuccess ? Colors.green.shade600 : Colors.red.shade600).withValues(alpha: 0.9),
                        child: Row(
                          children: [
                            Icon(
                              _scanSuccess ? Icons.check_circle_outline : Icons.error_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _scanSuccess ? _scanFeedback! : l10n.productNotFound,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      l10n.cameraPermissionRequired,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: openAppSettings,
                      child: Text(l10n.grantPermission, style: TextStyle(color: colorScheme.primary)),
                    ),
                  ],
                ),
              ),
        ),
      );
      },
    );
  }

  Widget _buildProductSelector() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, inventoryState) {
        List<Product> products = [];
        if (inventoryState is InventoryLoaded) products = inventoryState.products.where((p) => p.currentStock > 0).toList();

        return InkWell(
          onTap: () => _showProductSearchPicker(products),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.selectProductHint, style: TextStyle(color: colorScheme.onSurfaceVariant))),
                Icon(Icons.arrow_drop_down, color: colorScheme.outline),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductSearchPicker(List<Product> products) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final salesBloc = context.read<SalesBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        String query = '';
        final Map<int, int> itemQtys = {};

        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text(l10n.selectProduct, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setPickerState(() => query = v),
                    decoration: InputDecoration(
                      hintText: l10n.searchProduct,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outlineVariant)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 48, color: colorScheme.outlineVariant), const SizedBox(height: 16), Text(l10n.noDataFound, style: TextStyle(color: colorScheme.onSurfaceVariant))]))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final qty = itemQtys[product.id] ?? 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                            if (product.size != null && product.size!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                                                child: Text(product.size!, style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w500)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          l10n.stockInfo(l10n.formatDigits(product.currentStock.toString()), product.unit),
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildSmallQtyBtn(Icons.remove, () {
                                    setPickerState(() {
                                      if (qty > 1) itemQtys[product.id!] = qty - 1;
                                    });
                                  }),
                                  Container(
                                    width: 32,
                                    alignment: Alignment.center,
                                    child: Text(
                                      l10n.formatDigits(qty.toString()),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface),
                                    ),
                                  ),
                                  _buildSmallQtyBtn(Icons.add, () {
                                    setPickerState(() {
                                      if (qty < product.currentStock) itemQtys[product.id!] = qty + 1;
                                    });
                                  }),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      salesBloc.add(AddToCart(product, quantity: qty));
                                      HapticFeedback.lightImpact();
                                      Navigator.pop(modalContext);
                                    },
                                    icon: Icon(Icons.add_shopping_cart, color: colorScheme.primary, size: 22),
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.primaryContainer,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentTypeToggle(SalesDataLoaded state) {
    final l10n = context.l10n;
    return Row(
      children: [
        _buildToggleItem(l10n.cashPayment, PaymentType.cash, state.paymentType == PaymentType.cash, Colors.green),
        const SizedBox(width: 12),
        _buildToggleItem(l10n.creditPayment, PaymentType.credit, state.paymentType == PaymentType.credit, Colors.orange),
      ],
    );
  }

  Widget _buildToggleItem(String label, PaymentType type, bool isSelected, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: () {
           context.read<SalesBloc>().add(TogglePaymentType(type));
           if (type == PaymentType.cash) {
             setState(() => _isPartialPayment = false);
             _paidAmountController.text = '0';
           }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            border: Border.all(color: isSelected ? color : colorScheme.outlineVariant, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(label, style: TextStyle(color: isSelected ? color : colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildCustomerSelector(Customer? selectedCustomer) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        List<Customer> customers = [];
        if (state is CustomerLoaded) {
          customers = state.customers.where((c) => c.type == 'customer').toList();
        }

        return Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showSearchablePicker<Customer>(
                  title: l10n.selectCustomer,
                  items: customers,
                  itemLabel: (c) => c.name,
                  itemSublabel: (c) => c.phone,
                  onSelected: (c) => context.read<SalesBloc>().add(SelectCustomer(c)),
                  hintText: l10n.searchCustomer,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectedCustomer != null ? Colors.orange.withOpacity(0.08) : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: Border.all(color: selectedCustomer != null ? Colors.orange : colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: selectedCustomer != null ? Colors.orange : colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(child: Text(selectedCustomer?.name ?? l10n.selectCustomerHint, style: TextStyle(color: selectedCustomer != null ? Colors.orange : colorScheme.onSurfaceVariant, fontWeight: selectedCustomer != null ? FontWeight.bold : FontWeight.normal))),
                      Icon(Icons.arrow_drop_down, color: colorScheme.outline),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showAddCustomerDialog(context),
              icon: Icon(Icons.person_add_alt_1, color: colorScheme.primary),
              style: IconButton.styleFrom(backgroundColor: colorScheme.primary.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        );
      },
    );
  }

  void _showSearchablePicker<T>({required String title, required List<T> items, required String Function(T) itemLabel, String Function(T)? itemSublabel, required Function(T) onSelected, required String hintText}) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = items.where((item) => itemLabel(item).toLowerCase().contains(query.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setPickerState(() => query = v),
                    decoration: InputDecoration(hintText: hintText, prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outlineVariant)), contentPadding: EdgeInsets.zero),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 48, color: colorScheme.outlineVariant), const SizedBox(height: 16), Text(l10n.noDataFound, style: TextStyle(color: colorScheme.onSurfaceVariant))]))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(itemLabel(filtered[index]), style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: itemSublabel != null ? Text(itemSublabel(filtered[index])) : null,
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              onSelected(filtered[index]);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final l10n = context.l10n;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(l10n.addNewCustomer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: l10n.nameRequired, border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.phoneRequired, border: const OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) return;

              final db = context.read<DatabaseHelper>();
              final database = await db.database;

              final id = await database.insert(DatabaseConstants.tableCustomers, {
                DatabaseConstants.colName: nameController.text,
                DatabaseConstants.colPhone: phoneController.text,
                DatabaseConstants.colCustomerType: 'customer',
                DatabaseConstants.colCurrentCreditBalance: 0.0,
                DatabaseConstants.colTotalCredit: 0.0,
                DatabaseConstants.colTotalPaid: 0.0,
                DatabaseConstants.colTotalPurchases: 0.0,
                DatabaseConstants.colIsActive: 1,
                DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
                DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
                DatabaseConstants.colIsSynced: 0,
              });

              final newCustomer = Customer(
                id: id,
                name: nameController.text,
                phone: phoneController.text,
                address: '',
                currentCreditBalance: 0,
                totalPurchases: 0,
                isActive: true,
              );

              if (!context.mounted) return;
              context.read<CustomerBloc>().add(LoadCustomers());
              context.read<SalesBloc>().add(SelectCustomer(newCustomer));
              Navigator.pop(context);
            },
            child: Text(l10n.addLabel),
          ),
        ],
      ),
    );
  }
}
