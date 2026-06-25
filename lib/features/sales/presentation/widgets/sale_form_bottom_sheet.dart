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
import '../bloc/sales_bloc.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../screens/print_invoice_screen.dart';

class SaleFormBottomSheet extends StatefulWidget {
  const SaleFormBottomSheet({super.key});

  @override
  State<SaleFormBottomSheet> createState() => _SaleFormBottomSheetState();
}

class _SaleFormBottomSheetState extends State<SaleFormBottomSheet>
    with TickerProviderStateMixin {
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

  // Shake animation for checkout summary card
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // Scan line animation
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;

  String? _beepFilePath;
  String? _errorSoundFilePath;

  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(ClearCart());
    _scannerController = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    _requestCameraPermission();
    _initSoundFiles();

    // Shake animation: quick left-right jiggle
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    // Scan line: bounces top → bottom → top endlessly
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
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
    _shakeController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
    HapticFeedback.mediumImpact();
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
      _playErrorSound();
      _showScanFeedback('', false);
    } else if (product.currentStock <= 0) {
      HapticFeedback.heavyImpact();
      _playErrorSound();
      _showScanFeedback(product.name, false);
    } else {
      context.read<SalesBloc>().add(AddToCart(product));
      _playSuccessBeep();
      _triggerShake();
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

  Future<void> _initSoundFiles() async {
    try {
      final dir = await getTemporaryDirectory();

      // Success beep: high pitch 1400 Hz, 180ms
      final beepFile = File('${dir.path}/scan_success.wav');
      beepFile.writeAsBytesSync(_generateToneWav(frequency: 1400, durationMs: 180, amplitude: 0.7));
      if (mounted) _beepFilePath = beepFile.path;

      // Error buzz: two low 320 Hz pulses with a gap
      final errorFile = File('${dir.path}/scan_error.wav');
      errorFile.writeAsBytesSync(_generateErrorWav());
      if (mounted) _errorSoundFilePath = errorFile.path;
    } catch (_) {}
  }

  Future<void> _playSuccessBeep() async {
    if (_beepFilePath == null) return;
    try {
      final player = AudioPlayer();
      await player.setVolume(1.0);
      await player.play(DeviceFileSource(_beepFilePath!));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {}
  }

  Future<void> _playErrorSound() async {
    if (_errorSoundFilePath == null) return;
    try {
      final player = AudioPlayer();
      await player.setVolume(1.0);
      await player.play(DeviceFileSource(_errorSoundFilePath!));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {}
  }

  /// Generates a simple sine-wave WAV at [frequency] Hz for [durationMs] ms.
  Uint8List _generateToneWav({required int frequency, required int durationMs, double amplitude = 0.65}) {
    const sampleRate = 44100;
    final numSamples = sampleRate * durationMs ~/ 1000;
    final pcm = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double env = 1.0;
      if (i < numSamples * 0.05) env = i / (numSamples * 0.05);
      else if (i > numSamples * 0.85) env = (numSamples - i) / (numSamples * 0.15);
      pcm[i] = (sin(2 * pi * frequency * t) * amplitude * 32767 * env).round().clamp(-32768, 32767);
    }
    return _wrapPcmInWav(pcm, sampleRate);
  }

  /// Generates a double low-buzz error sound (two 320 Hz pulses separated by silence).
  Uint8List _generateErrorWav() {
    const sampleRate = 44100;
    const frequency = 320;
    const pulseMs = 120;
    const gapMs = 80;
    const pulseSamples = sampleRate * pulseMs ~/ 1000;
    const gapSamples = sampleRate * gapMs ~/ 1000;
    final numSamples = pulseSamples + gapSamples + pulseSamples;
    final pcm = Int16List(numSamples);
    for (int pass = 0; pass < 2; pass++) {
      final offset = pass * (pulseSamples + gapSamples);
      for (int i = 0; i < pulseSamples; i++) {
        final t = i / sampleRate;
        double env = 1.0;
        if (i < pulseSamples * 0.1) env = i / (pulseSamples * 0.1);
        else if (i > pulseSamples * 0.8) env = (pulseSamples - i) / (pulseSamples * 0.2);
        pcm[offset + i] = (sin(2 * pi * frequency * t) * 0.8 * 32767 * env).round().clamp(-32768, 32767);
      }
    }
    return _wrapPcmInWav(pcm, sampleRate);
  }

  Uint8List _wrapPcmInWav(Int16List pcm, int sampleRate) {
    final dataSize = pcm.length * 2;
    final bd = ByteData(44 + dataSize);
    // RIFF
    [0x52,0x49,0x46,0x46].asMap().forEach((i,v)=>bd.setUint8(i,v));
    bd.setUint32(4, 36 + dataSize, Endian.little);
    [0x57,0x41,0x56,0x45].asMap().forEach((i,v)=>bd.setUint8(8+i,v));
    // fmt
    [0x66,0x6D,0x74,0x20].asMap().forEach((i,v)=>bd.setUint8(12+i,v));
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    // data
    [0x64,0x61,0x74,0x61].asMap().forEach((i,v)=>bd.setUint8(36+i,v));
    bd.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < pcm.length; i++) bd.setInt16(44 + i * 2, pcm[i], Endian.little);
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
          final sale = state.sale;
          Navigator.of(context).pop(); // close bottom sheet
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PrintInvoiceScreen(sale: sale)),
          );
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
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.newSaleInvoice,
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                    ),
                                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _ScannerHeaderDelegate(
                            backgroundColor: colorScheme.surface,
                            height: 220, // 210 (scanner) + 10 (padding)
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildScannerBox(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 16).copyWith(
                              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Selection Section
                                _buildSectionHeader('📦 ${l10n.selectProduct}', colorScheme.primary),
                                const SizedBox(height: 12),
                                _buildProductSelector(),

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
                                  _buildTextField(
                                      _discountController, l10n.discountTaka,
                                      prefix: '৳',
                                      isNumber: true,
                                      onChanged: (_) => setState(() {}),
                                      focusNode: _discountFocus,
                                      textInputAction: TextInputAction.next,
                                      nextFocus: _notesFocus),
                                ],

                                const SizedBox(height: 16),
                                _buildTextField(_notesController, '💬 ${l10n.additionalNotes}', maxLines: 2, focusNode: _notesFocus),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sticky checkout summary card
                  _buildStickyCheckoutSummary(state, finalTotal, l10n, colorScheme),
                ],
              ),
            );
          },
        ),
        );
      },
    );
  }

  Widget _buildStickyCheckoutSummary(
    SalesDataLoaded state,
    double finalTotal,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, -4)),
        ],
      ),
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) => Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        ),
        child: _buildCheckoutSummary(state, finalTotal, l10n, colorScheme),
      ),
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

  Widget _buildCheckoutSummary(SalesDataLoaded state, double finalTotal, AppLocalizations l10n, ColorScheme colorScheme) {
    double paid = double.tryParse(_paidAmountController.text) ?? 0;
    if (state.paymentType == PaymentType.cash) paid = finalTotal;

    double due = finalTotal - paid;
    if (due < 0) due = 0;

    final canCheckout = !state.isSubmitting && state.cart.isNotEmpty;
    final totalQty = state.cart.fold<int>(0, (sum, item) => sum + item.quantity);
    final itemCount = state.cart.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Summary info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Item count + qty badges
                if (state.cart.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        _summaryBadge('$itemCount ${itemCount == 1 ? 'item' : 'items'}', colorScheme.primary.withValues(alpha: 0.12), colorScheme.primary),
                        const SizedBox(width: 6),
                        _summaryBadge('$totalQty qty', Colors.orange.withValues(alpha: 0.12), Colors.orange.shade700),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Text(l10n.subTotal, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.55))),
                    const SizedBox(width: 4),
                    Text('৳${l10n.formatAmount(state.totalAmount)}', style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.55))),
                    if ((double.tryParse(_discountController.text) ?? 0) > 0) ...[
                      const SizedBox(width: 8),
                      Text('- ৳${l10n.formatAmount(double.tryParse(_discountController.text) ?? 0)}', style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '৳${l10n.formatAmount(finalTotal)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
                if (state.paymentType == PaymentType.credit) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(l10n.collectedColon, style: TextStyle(fontSize: 11, color: Colors.green.shade400)),
                      const SizedBox(width: 4),
                      Text('৳${l10n.formatAmount(paid)}', style: TextStyle(fontSize: 11, color: Colors.green.shade400, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Text(l10n.dueRemaining, style: TextStyle(fontSize: 11, color: Colors.orange.shade400)),
                      const SizedBox(width: 4),
                      Text('৳${l10n.formatAmount(due)}', style: TextStyle(fontSize: 11, color: Colors.orange.shade400, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Confirm arrow button
          GestureDetector(
            onTap: canCheckout ? () => _handleCheckout(state, finalTotal) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: canCheckout ? Colors.green.shade600 : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(14),
                boxShadow: canCheckout
                    ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: state.isSubmitting
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w600)),
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
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 210,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _cameraPermissionGranted
                ? Stack(
                    children: [
                      // Camera feed
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) => _onBarcodeScanned(capture, products),
                      ),
                      // Dark overlay outside the scan zone
                      CustomPaint(
                        size: Size.infinite,
                        painter: _ScanOverlayPainter(),
                      ),
                      // Animated red scan line inside the frame
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _scanLineAnimation,
                          builder: (context, _) {
                            const frameH = 90.0;
                            const frameTop = (210 - frameH) / 2; // vertically centred
                            final lineY = frameTop + _scanLineAnimation.value * (frameH - 2);
                            return CustomPaint(
                              painter: _ScanLinePainter(lineY: lineY),
                            );
                          },
                        ),
                      ),
                      // Corner brackets (the scanner-style frame)
                      Center(
                        child: SizedBox(
                          width: 240,
                          height: 90,
                          child: CustomPaint(painter: _CornerBracketPainter()),
                        ),
                      ),
                      // Top label
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_scanner, color: Colors.white70, size: 13),
                                const SizedBox(width: 5),
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                            color: (_scanSuccess ? Colors.green.shade600 : Colors.red.shade700).withValues(alpha: 0.92),
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
                                      _triggerShake();
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

// ── Scanner UI painters & delegates ──────────────────────────────────────────────────────

class _ScannerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color backgroundColor;

  _ScannerHeaderDelegate({
    required this.child,
    required this.height,
    required this.backgroundColor,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      margin: EdgeInsets.only(left: 20, right: 20, top: 20),
      color: backgroundColor, // hides scrolled content behind it
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _ScannerHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// Semi-transparent dark overlay everywhere EXCEPT the central scan window.
class _ScanOverlayPainter extends CustomPainter {
  static const double _frameW = 240;
  static const double _frameH = 90;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: _frameW, height: _frameH);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Four corner brackets (L-shapes) at the corners of the scan frame.
class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 20.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Horizontal glowing red scan line that travels up and down inside the frame.
class _ScanLinePainter extends CustomPainter {
  final double lineY;
  const _ScanLinePainter({required this.lineY});

  static const double _frameW = 240;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final left = cx - _frameW / 2 + 8;
    final right = cx + _frameW / 2 - 8;

    // Main gradient red line
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.red.withValues(alpha: 0.0),
          Colors.red.shade500,
          Colors.red.shade300,
          Colors.red.shade500,
          Colors.red.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(left, lineY, right, lineY + 2))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(left, lineY), Offset(right, lineY), paint);

    // Soft glow halo
    final glowPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(left, lineY), Offset(right, lineY), glowPaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.lineY != lineY;
}
