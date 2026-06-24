import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/invoice_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../domain/sale.dart';
import 'receipt_settings_screen.dart';

class PrintInvoiceScreen extends StatefulWidget {
  final Sale sale;
  const PrintInvoiceScreen({super.key, required this.sale});

  @override
  State<PrintInvoiceScreen> createState() => _PrintInvoiceScreenState();
}

class _PrintInvoiceScreenState extends State<PrintInvoiceScreen> {
  late int _copies;
  bool _isPrinting = false;
  bool _isSharing = false;

  Sale get sale => widget.sale;

  @override
  void initState() {
    super.initState();
    _copies = context.read<AppSettingsCubit>().state.defaultCopies;
  }

  Future<void> _handlePrint() async {
    if (_isPrinting || _isSharing) return;
    setState(() => _isPrinting = true);
    final settings = context.read<AppSettingsCubit>().state;
    try {
      await InvoiceService.printReceipt(sale, settings, copies: _copies);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('প্রিন্ট ব্যর্থ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isPrinting || _isSharing) return;
    setState(() => _isSharing = true);
    final settings = context.read<AppSettingsCubit>().state;
    try {
      await InvoiceService.shareReceipt(sale, settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('শেয়ার ব্যর্থ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _openReceiptSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptSettingsScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = context.read<AppSettingsCubit>().state.isBangla;
    final busy = _isPrinting || _isSharing;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text(
          isBangla ? 'ইনভয়েস প্রিন্ট' : 'Print Invoice',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
                builder: (ctx, settings) => GestureDetector(
                  onTap: _openReceiptSettings,
                  child: _buildReceiptCard(settings),
                ),
              ),
            ),
          ),
          if (busy)
            LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primary,
            ),
          _buildControlsPanel(isBangla, busy),
        ],
      ),
    );
  }

  // ── Template dispatcher ───────────────────────────────────

  Widget _buildReceiptCard(AppSettingsState s) {
    switch (s.receiptTemplate) {
      case 1:
        return _detailedPosPreview(s);
      case 2:
        return _bigFontPreview(s);
      case 3:
        return _qrCodePreview(s);
      case 4:
        return _barcodePreview(s);
      case 5:
        return _ticketPreview(s);
      case 6:
        return _a4Style1Preview(s);
      default:
        return _standardPreview(s);
    }
  }

  // ── Template 0: Standard ─────────────────────────────────

  Widget _standardPreview(AppSettingsState s) {
    final L = _lbl(s.isBangla);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + sale.discount;
    final items = _sortedItems(s);

    return _receiptShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Column(children: [
            Icon(Icons.store_mall_directory_outlined, size: 52, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(s.shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            if (s.shopAddress.isNotEmpty) Text(s.shopAddress, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
            if (s.shopPhone.isNotEmpty) Text(s.shopPhone, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(s.receiptTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ]),
          const SizedBox(height: 10),
          _dash(),
          _meta(L['inv']!, '${s.invoiceIdPrefix}${sale.invoiceId}'),
          _dash(),
          _meta(L['date']!, dateStr),
          _dash(),
          if (s.printCustomerInfo && sale.customerName != null) ...[
            _meta(L['cust']!, sale.customerName!),
            _dash(),
          ],
          // Items header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const SizedBox(width: 20, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 6),
              Expanded(child: Text(L['prod']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 62, child: Text(L['rate']!, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 36, child: Text(L['qty']!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 70, child: Text(L['amt']!, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          _dash(),
          // Items
          ...items.asMap().entries.map((e) {
            final item = e.value;
            final n = e.key + 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 20, child: Text('$n', style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13))),
                  SizedBox(width: 62, child: Text('৳${item.unitPrice.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                  SizedBox(width: 36, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                  SizedBox(width: 70, child: Text('৳${item.subTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                ]),
              ),
              _dash(),
            ]);
          }),
          const SizedBox(height: 6),
          _sumRow(L['priceAmt']!, subtotal),
          const SizedBox(height: 8),
          _sumRow(L['billAmt']!, sale.totalAmount),
          const SizedBox(height: 8),
          _sumRow(L['paid']!, sale.paidAmount),
          _dash(),
          _meta(L['payMethod']!, isCash ? L['cash']! : L['cred']!),
          if (sale.dueAmount > 0) ...[_dash(), _meta(L['due']!, '৳${sale.dueAmount.toStringAsFixed(2)}', valueColor: Colors.red)],
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[_dash(), _meta(L['note']!, sale.notes!)],
          if (s.receiptFooter.isNotEmpty) ...[const SizedBox(height: 10), Text(s.receiptFooter, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black87))],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Template 1: Detailed POS ─────────────────────────────

  Widget _detailedPosPreview(AppSettingsState s) {
    final isBn = s.isBangla;
    final L = _lbl(isBn);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + sale.discount;
    final items = _sortedItems(s);
    final totalQty = sale.items.fold<int>(0, (sum, it) => sum + it.quantity);
    final bdr = s.enableTableBorder ? BorderSide(color: Colors.grey.shade700, width: 0.5) : BorderSide.none;

    return _receiptShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (compact, no icon)
          Text(s.shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          if (s.shopAddress.isNotEmpty) Text(s.shopAddress, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
          if (s.shopPhone.isNotEmpty) Text(s.shopPhone, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Container(height: 1, color: Colors.black),
          const SizedBox(height: 4),
          Text(
            '${isBn ? "ইনভয়েস নং" : "Inv No"}${s.invoiceIdPrefix}${sale.invoiceId}  '
            '${isBn ? "তারিখ" : "Date"}:$dateStr  '
            '${isBn ? "পেমেন্ট" : "Payment"}:${isCash ? (isBn ? "নগদ" : "CASH") : (isBn ? "বাকি" : "CREDIT")}',
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 6),
          // Items table
          Table(
            border: TableBorder(
              top: bdr, bottom: bdr, left: bdr, right: bdr,
              horizontalInside: bdr, verticalInside: bdr,
            ),
            columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(2)},
            children: [
              _tableRow([isBn ? 'পণ্যের নাম' : 'Item Description', L['rate']!, isBn ? 'ছাড়' : 'Disc', isBn ? 'মোট' : 'Unit Amt'], header: true),
              for (final it in items) ...[
                _tableRow([it.productName, '৳${it.unitPrice.toStringAsFixed(2)}', '0.00', '৳${it.subTotal.toStringAsFixed(2)}']),
                _tableRow(['${it.quantity}', '', '', ''], small: true),
              ],
              _tableRow(['${isBn ? "মোট পরিমাণ" : "Total Qty"}: $totalQty', '', '${isBn ? "মোট পণ্য" : "Total Items"}: ${items.length}', ''], small: true),
            ],
          ),
          const SizedBox(height: 6),
          // Summary
          if (s.printCustomerInfo && sale.customerName != null)
            _meta(isBn ? 'ক্রেতা:' : 'Customer:', sale.customerName!),
          _metaRow(isBn ? 'মোট' : 'Sub Total', '৳${subtotal.toStringAsFixed(2)}'),
          _metaRow(isBn ? 'সর্বমোট' : 'Grand Total', '৳${sale.totalAmount.toStringAsFixed(2)}', bold: true),
          _metaRow(s.customPayableLabel, '৳${sale.paidAmount.toStringAsFixed(2)}'),
          if (s.enablePaymentInfo) ...[
            const SizedBox(height: 8),
            Text(isBn ? 'পেমেন্ট তথ্য' : 'Payment Information', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Table(
              border: TableBorder.all(width: 0.5, color: Colors.grey.shade700),
              children: [
                _tableRow([isBn ? 'তারিখ' : 'Date', isBn ? 'পরিশোধ' : 'Paid', isBn ? 'বাকি' : 'Due'], header: true),
                _tableRow([
                  DateFormat('dd-MM-yyyy').format(sale.saleDate),
                  '৳${sale.paidAmount.toStringAsFixed(2)}(${isCash ? (isBn ? "নগদ" : "CASH") : (isBn ? "বাকি" : "CREDIT")})',
                  '৳${sale.dueAmount.toStringAsFixed(2)}',
                ]),
              ],
            ),
          ],
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[const SizedBox(height: 6), Text(sale.notes!, style: const TextStyle(fontSize: 11))],
          if (s.receiptFooter.isNotEmpty) ...[const SizedBox(height: 8), Text(s.receiptFooter, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87))],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Template 2: Big Font ──────────────────────────────────

  Widget _bigFontPreview(AppSettingsState s) {
    final isBn = s.isBangla;
    final L = _lbl(isBn);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + sale.discount;
    final items = _sortedItems(s);

    return _receiptShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          if (s.shopAddress.isNotEmpty) Text(s.shopAddress, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          if (s.shopPhone.isNotEmpty) Text(s.shopPhone, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          Text(s.receiptTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          _solidLine(),
          Text(isBn ? 'বিক্রয় বিবরণ' : 'Invoice Details', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${isBn ? "অর্ডার আইডি" : "Order ID"}:${s.invoiceIdPrefix}${sale.invoiceId}', style: const TextStyle(fontSize: 13)),
          Text('${isBn ? "তারিখ" : "Date"}:$dateStr', style: const TextStyle(fontSize: 13)),
          Text('${isBn ? "পেমেন্ট পদ্ধতি" : "Payment Method"}:${isCash ? (isBn ? "নগদ" : "Cash") : (isBn ? "বাকি" : "Credit")}', style: const TextStyle(fontSize: 13)),
          if (s.printCustomerInfo && sale.customerName != null)
            Text('${isBn ? "ক্রেতা" : "Customer"}: ${sale.customerName}', style: const TextStyle(fontSize: 13)),
          _solidLine(),
          Row(children: [
            Expanded(child: Text(L['prod']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            Text(L['amt']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          for (final it in items) ...[
            Container(height: 0.5, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(vertical: 2)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.productName, style: const TextStyle(fontSize: 14)),
                Text('${it.quantity} X ৳${it.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ])),
              Text('৳${it.subTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ],
          _solidLine(),
          _bigRow(isBn ? 'মোট' : 'Sub Total', '৳${subtotal.toStringAsFixed(2)}'),
          _bigRow(s.customPayableLabel, '৳${sale.totalAmount.toStringAsFixed(2)}', bold: true),
          if (sale.dueAmount > 0)
            _bigRow(isBn ? 'বাকি' : 'Due', '৳${sale.dueAmount.toStringAsFixed(2)}', color: Colors.red),
          if (s.receiptFooter.isNotEmpty) ...[const SizedBox(height: 12), Text(s.receiptFooter, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black87))],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Template 3: QR Code ───────────────────────────────────

  Widget _qrCodePreview(AppSettingsState s) {
    final qrData = s.qrCodeData.isNotEmpty ? s.qrCodeData : sale.invoiceId;
    return Column(
      children: [
        _standardPreview(s),
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Center(
            child: Column(children: [
              CustomPaint(size: const Size(90, 90), painter: _QrPainter()),
              const SizedBox(height: 4),
              Text(qrData, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Template 4: Barcode ───────────────────────────────────

  Widget _barcodePreview(AppSettingsState s) {
    return Column(
      children: [
        _standardPreview(s),
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Center(
            child: Column(children: [
              CustomPaint(size: const Size(160, 50), painter: _BarcodePainter(sale.invoiceId)),
              const SizedBox(height: 4),
              Text(sale.invoiceId, style: TextStyle(fontSize: 9, letterSpacing: 2, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Template 5: Ticket ────────────────────────────────────

  Widget _ticketPreview(AppSettingsState s) {
    final isBn = s.isBangla;
    final dateStr = _fmtDate(sale.saleDate, true);
    final items = _sortedItems(s);

    return _receiptShell(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(s.shopName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          if (s.shopAddress.isNotEmpty) Text(s.shopAddress, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          if (s.shopPhone.isNotEmpty) Text(s.shopPhone, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            '${isBn ? "টিকেট" : "Ticket"}:${sale.invoiceId}  ${isBn ? "তারিখ" : "Date"}:$dateStr',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Bordered item table
          Container(
            decoration: BoxDecoration(border: Border.all(width: 2)),
            child: Column(
              children: [
                for (final it in items) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(it.productName, style: const TextStyle(fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(width: 2))),
                    child: Row(children: [
                      Expanded(child: Text('${it.quantity}.0 X ${it.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13))),
                      Text(it.subTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
                // Total row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(width: 2))),
                  child: Row(children: [
                    Expanded(child: Text(isBn ? 'টাকা' : 'BDT', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    Text('৳${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ],
            ),
          ),
          if (sale.dueAmount > 0) ...[const SizedBox(height: 6), Text('${isBn ? "বাকি" : "Due"}: ৳${sale.dueAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold))],
          if (s.receiptFooter.isNotEmpty) ...[const SizedBox(height: 12), Text(s.receiptFooter, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87))],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Template 6: A4-Style 1 ────────────────────────────────

  Widget _a4Style1Preview(AppSettingsState s) {
    final isBn = s.isBangla;
    final L = _lbl(isBn);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + sale.discount;
    final items = _sortedItems(s);

    return _receiptShell(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(s.shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          if (s.shopAddress.isNotEmpty) Text(s.shopAddress, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          if (s.shopPhone.isNotEmpty) Text(s.shopPhone, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          Container(height: 2, color: Colors.black, margin: const EdgeInsets.symmetric(vertical: 10)),
          // Invoice details
          Text(isBn ? 'বিক্রয় বিবরণ' : 'Invoice Details', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${isBn ? "অর্ডার আইডি" : "Order ID"}:${s.invoiceIdPrefix}${sale.invoiceId}', style: const TextStyle(fontSize: 12)),
          Text('${isBn ? "তারিখ" : "Date"}:$dateStr', style: const TextStyle(fontSize: 12)),
          Text('${isBn ? "পেমেন্ট পদ্ধতি" : "Payment Method"}:${isCash ? (isBn ? "নগদ" : "Cash") : (isBn ? "বাকি" : "Credit")}', style: const TextStyle(fontSize: 12)),
          if (s.printCustomerInfo && sale.customerName != null)
            Text('${isBn ? "ক্রেতা" : "Customer"}: ${sale.customerName}', style: const TextStyle(fontSize: 12)),
          Container(height: 1, color: Colors.grey.shade400, margin: const EdgeInsets.symmetric(vertical: 8)),
          // Items table
          Table(
            border: TableBorder.all(width: 0.5, color: Colors.grey.shade500),
            columnWidths: const {0: FixedColumnWidth(30), 1: FlexColumnWidth(3), 2: FlexColumnWidth(2), 3: FixedColumnWidth(30), 4: FlexColumnWidth(2)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  for (final h in [isBn ? 'ক্রমিক' : 'SINo', L['prod']!, L['rate']!, L['qty']!, isBn ? 'মোট' : 'Total'])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: h == L['prod']! ? TextAlign.left : TextAlign.center),
                    ),
                ],
              ),
              for (int i = 0; i < items.length; i++)
                TableRow(
                  decoration: BoxDecoration(color: i.isEven ? Colors.white : Colors.grey.shade50),
                  children: [
                    _tableCell('${i + 1}', center: true),
                    _tableCell(items[i].productName),
                    _tableCell('৳${items[i].unitPrice.toStringAsFixed(2)}', center: true),
                    _tableCell('${items[i].quantity}', center: true),
                    _tableCell('৳${items[i].subTotal.toStringAsFixed(2)}', center: true, bold: true),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Summary (right-aligned)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 220,
              child: Column(children: [
                _sumRow(isBn ? 'মোট' : 'Sub Total', subtotal, fontSize: 12),
                if (sale.discount > 0) _sumRow(isBn ? 'ছাড়' : 'Discount', -sale.discount, fontSize: 12, color: Colors.red),
                Container(height: 2, color: Colors.black, margin: const EdgeInsets.symmetric(vertical: 4)),
                _sumRow(isBn ? 'সর্বমোট' : 'Grand Total', sale.totalAmount, fontSize: 14, bold: true),
                _sumRow(L['paid']!, sale.paidAmount, fontSize: 12, color: Colors.green),
                if (sale.dueAmount > 0) _sumRow(isBn ? 'বাকি' : 'Due', sale.dueAmount, fontSize: 12, color: Colors.red, bold: true),
              ]),
            ),
          ),
          if (s.receiptFooter.isNotEmpty) ...[const SizedBox(height: 20), Text(s.receiptFooter, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black87))],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Controls panel ────────────────────────────────────────

  Widget _buildControlsPanel(bool isBangla, bool busy) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBangla ? 'কপির সংখ্যা' : 'Number of copy',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Row(children: [
                _stepperBtn(Icons.remove, (!busy && _copies > 1) ? () => setState(() => _copies--) : null),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('$_copies', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                _stepperBtn(Icons.add, (!busy && _copies < 20) ? () => setState(() => _copies++) : null),
              ]),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: busy ? null : _handlePrint,
                child: _isPrinting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.print, size: 20),
                          const SizedBox(width: 6),
                          Text(isBangla ? 'প্রিন্ট' : 'Print', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.primary),
            onPressed: busy ? null : _openReceiptSettings,
            tooltip: 'রসিদ সেটিংস',
          ),
          IconButton(
            icon: _isSharing
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant))
                : const Icon(Icons.share_outlined, color: AppColors.primary),
            onPressed: busy ? null : _handleShare,
            tooltip: 'শেয়ার',
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────

  List<SaleItem> _sortedItems(AppSettingsState s) {
    if (s.sortItemsAlphabetical) {
      return List.from(sale.items)..sort((a, b) => a.productName.compareTo(b.productName));
    }
    return sale.items;
  }

  String _fmtDate(DateTime d, bool showTime) {
    final date = DateFormat('dd/MM/yyyy').format(d);
    return showTime ? '$date ${DateFormat('hh:mm a').format(d)}' : date;
  }

  Widget _receiptShell({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) =>
      Container(color: Theme.of(context).colorScheme.surface, padding: padding, child: child);

  Widget _solidLine() => Container(height: 1, color: Colors.black87, margin: const EdgeInsets.symmetric(vertical: 6));

  Widget _dash() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: SizedBox(height: 1, child: CustomPaint(painter: _DashPainter())),
      );

  Widget _meta(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const Spacer(),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor))),
        ]),
      );

  Widget _metaRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  Widget _bigRow(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
        ]),
      );

  Widget _sumRow(String label, double amount, {double fontSize = 14, bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color))),
          Text('৳${amount.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
        ]),
      );

  Widget _stepperBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: onTap != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outlineVariant),
        ),
      );

  TableRow _tableRow(List<String> cells, {bool header = false, bool small = false}) => TableRow(
        decoration: header ? BoxDecoration(color: Colors.grey.shade200) : null,
        children: cells.map((c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Text(c, style: TextStyle(fontSize: small ? 9 : 10, fontWeight: header ? FontWeight.bold : FontWeight.normal)),
        )).toList(),
      );

  Widget _tableCell(String text, {bool center = false, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Text(text, textAlign: center ? TextAlign.center : TextAlign.left, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );

  Map<String, String> _lbl(bool bn) => bn
      ? {
          'inv': 'ইনভয়েস নং',
          'date': 'তারিখ',
          'cust': 'ক্রেতার নাম',
          'prod': 'পণ্যের নাম',
          'qty': 'পরিমাণ',
          'rate': 'মূল্য',
          'amt': 'মোট',
          'priceAmt': 'মূল্য পরিমাণ',
          'billAmt': 'বিল পরিমাণ',
          'paid': 'পরিশোধিত',
          'payMethod': 'পেমেন্ট পদ্ধতি',
          'cash': 'নগদ',
          'cred': 'বাকি',
          'due': 'বাকি পরিমাণ',
          'note': 'নোট',
        }
      : {
          'inv': 'Invoice No',
          'date': 'Date',
          'cust': 'Customer Name',
          'prod': 'Item Name',
          'qty': 'Qty',
          'rate': 'Price',
          'amt': 'Amount',
          'priceAmt': 'Sub Total',
          'billAmt': 'Grand Total',
          'paid': 'Paid',
          'payMethod': 'Payment Method',
          'cash': 'Cash',
          'cred': 'Credit',
          'due': 'Due Amount',
          'note': 'Note',
        };
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.shade400..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + dash, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    final cell = size.width / 7;
    _finder(canvas, p, 0, 0, cell);
    _finder(canvas, p, 4 * cell, 0, cell);
    _finder(canvas, p, 0, 4 * cell, cell);
    for (final c in [[2, 2], [3, 3], [2, 4], [4, 2], [3, 5], [5, 3], [4, 4], [5, 5], [6, 4]]) {
      canvas.drawRect(Rect.fromLTWH(c[0] * cell, c[1] * cell, cell - 0.5, cell - 0.5), p);
    }
  }

  void _finder(Canvas canvas, Paint p, double x, double y, double cell) {
    canvas.drawRect(Rect.fromLTWH(x, y, 3 * cell, 3 * cell), p);
    canvas.drawRect(Rect.fromLTWH(x + 0.5, y + 0.5, 3 * cell - 1, 3 * cell - 1), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(x + cell, y + cell, cell, cell), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BarcodePainter extends CustomPainter {
  final String seed;
  const _BarcodePainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    final chars = seed.codeUnits;
    double x = 0;
    final barCount = 36;
    final unitW = size.width / (barCount * 2.2);
    for (int i = 0; i < barCount; i++) {
      final c = chars[i % chars.length];
      final w = ((c % 3) + 1) * unitW;
      final h = size.height * (0.6 + (c % 4) * 0.1);
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w - 0.5, h), p);
      }
      x += w + unitW * 0.3;
      if (x >= size.width) break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
