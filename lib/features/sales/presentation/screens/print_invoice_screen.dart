import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/invoice_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../domain/sale.dart';

class PrintInvoiceScreen extends StatefulWidget {
  final Sale sale;
  const PrintInvoiceScreen({super.key, required this.sale});

  @override
  State<PrintInvoiceScreen> createState() => _PrintInvoiceScreenState();
}

class _PrintInvoiceScreenState extends State<PrintInvoiceScreen> {
  int _copies = 2;
  bool _isPrinting = false;
  bool _isSharing = false;

  Sale get sale => widget.sale;

  Future<void> _handlePrint() async {
    if (_isPrinting || _isSharing) return;
    setState(() => _isPrinting = true);

    final isBangla = context.l10n.isBangla;
    final settings = context.read<AppSettingsCubit>().state;
    try {
      await InvoiceService.printReceipt(
        sale,
        isBangla: isBangla,
        copies: _copies,
        shopName: settings.shopName,
        shopAddress: settings.shopAddress,
        shopPhone: settings.shopPhone,
      );
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

    final isBangla = context.l10n.isBangla;
    final settings = context.read<AppSettingsCubit>().state;
    try {
      await InvoiceService.shareReceipt(
        sale,
        isBangla: isBangla,
        shopName: settings.shopName,
        shopAddress: settings.shopAddress,
        shopPhone: settings.shopPhone,
      );
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

  void _showShopSettings() {
    final settings = context.read<AppSettingsCubit>().state;
    final nameCtrl = TextEditingController(text: settings.shopName);
    final addrCtrl = TextEditingController(text: settings.shopAddress);
    final phoneCtrl = TextEditingController(text: settings.shopPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('দোকানের তথ্য'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'দোকানের নাম'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(labelText: 'ঠিকানা'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'ফোন নম্বর'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppSettingsCubit>().setShopInfo(
                    name: nameCtrl.text.trim().isEmpty
                        ? 'আমার দোকান'
                        : nameCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  );
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = context.l10n.isBangla;
    final busy = _isPrinting || _isSharing;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
        title: Text(
          isBangla ? 'ইনভয়েস প্রিন্ট' : 'Print Invoice',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
                builder: (ctx, settings) =>
                    _buildReceiptCard(ctx, settings, isBangla),
              ),
            ),
          ),
          if (busy)
            LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF3D5AFE),
            ),
          _buildControlsPanel(isBangla, busy),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(bool isBangla, bool busy) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16,20),
      child: Row(
        children: [
          // Copy stepper
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBangla ? 'কপির সংখ্যা' : 'Number of copy',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _stepperBtn(
                    Icons.remove,
                    (!busy && _copies > 1) ? () => setState(() => _copies--) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '$_copies',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _stepperBtn(
                    Icons.add,
                    (!busy && _copies < 20) ? () => setState(() => _copies++) : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Print button
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5AFE),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: busy ? null : _handlePrint,
                child: _isPrinting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.print, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            isBangla ? 'প্রিন্ট' : 'Print',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF3D5AFE)),
            onPressed: busy ? null : _showShopSettings,
            tooltip: 'দোকানের তথ্য',
          ),
          // Share
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black54),
                  )
                : const Icon(Icons.share_outlined, color: Colors.black54),
            onPressed: busy ? null : _handleShare,
            tooltip: 'শেয়ার',
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? Colors.black : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildReceiptCard(
      BuildContext context, AppSettingsState settings, bool isBangla) {
    final L = _lbl(isBangla);
    final dateStr = DateFormat('dd/MM/yyyy').format(sale.saleDate);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + sale.discount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────
          Column(children: [
            const Icon(Icons.store_mall_directory_outlined,
                size: 52, color: Colors.grey),
            const SizedBox(height: 6),
            Text(settings.shopName,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            if (settings.shopAddress.isNotEmpty)
              Text(settings.shopAddress,
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center),
            if (settings.shopPhone.isNotEmpty)
              Text(settings.shopPhone,
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(L['title']!,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ]),
          const SizedBox(height: 10),

          // ── Meta rows ─────────────────────────────────────────
          _dash(),
          _meta(L['inv']!, sale.invoiceId),
          _dash(),
          _meta(L['date']!, dateStr),
          _dash(),
          if (sale.customerName != null) ...[
            _meta(L['cust']!, sale.customerName!),
            _dash(),
          ],

          // ── Items header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const SizedBox(
                  width: 20,
                  child: Text('#',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(L['prod']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
              SizedBox(
                  width: 62,
                  child: Text(L['rate']!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
              SizedBox(
                  width: 36,
                  child: Text(L['qty']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
              SizedBox(
                  width: 70,
                  child: Text(L['amt']!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
            ]),
          ),
          _dash(),

          // ── Item rows ─────────────────────────────────────────
          ...sale.items.asMap().entries.map((e) {
            final item = e.value;
            final n = e.key + 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 20,
                          child:
                              Text('$n', style: const TextStyle(fontSize: 13))),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(item.productName,
                              style: const TextStyle(fontSize: 13))),
                      SizedBox(
                          width: 62,
                          child: Text(
                              '৳${item.unitPrice.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13))),
                      SizedBox(
                          width: 36,
                          child: Text('${item.quantity}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13))),
                      SizedBox(
                          width: 70,
                          child: Text(
                              '৳${item.subTotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold))),
                    ]),
              ),
              _dash(),
            ]);
          }),

          // ── Summary ───────────────────────────────────────────
          const SizedBox(height: 6),
          _sumRow(L['priceAmt']!, subtotal),
          const SizedBox(height: 10),
          _sumRow(L['billAmt']!, sale.totalAmount, smallLabel: true),
          const SizedBox(height: 10),
          _sumRow(L['paid']!, sale.paidAmount),
          _dash(),
          _meta(L['payMethod']!, isCash ? L['cash']! : L['cred']!),

          if (sale.dueAmount > 0) ...[
            _dash(),
            _meta(L['due']!, '৳${sale.dueAmount.toStringAsFixed(2)}',
                valueColor: Colors.red),
          ],
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            _dash(),
            _meta(L['note']!, sale.notes!),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _dash() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: SizedBox(
          height: 1,
          child: CustomPaint(painter: _DashPainter()),
        ),
      );

  Widget _meta(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 14, color: Colors.black87)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: valueColor)),
            ),
          ],
        ),
      );

  Widget _sumRow(String label, double amount, {bool smallLabel = false}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: smallLabel ? 13 : 14,
                      color: Colors.black87))),
          Text('৳${amount.toStringAsFixed(2)}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      );

  Map<String, String> _lbl(bool bn) => bn
      ? {
          'title': 'বিক্রয় চালান',
          'inv': 'ইনভয়েস নং',
          'date': 'তারিখ',
          'cust': 'ক্রেতার নাম',
          'prod': 'পণ্যের নাম',
          'qty': 'পরিমাণ',
          'rate': 'মূল্য',
          'amt': 'মোট',
          'priceAmt': 'মূল্য পরিমাণ',
          'billAmt': 'বিল পরিমাণ (ছাড় ও অতিরিক্ত চার্জ সহ)',
          'paid': 'পরিশোধিত',
          'payMethod': 'পেমেন্ট পদ্ধতি',
          'cash': 'নগদ',
          'cred': 'বাকি',
          'due': 'বাকি পরিমাণ',
          'note': 'নোট',
        }
      : {
          'title': 'Sales Invoice',
          'inv': 'Invoice No',
          'date': 'Date',
          'cust': 'Customer Name',
          'prod': 'Item Name',
          'qty': 'Qty',
          'rate': 'Price',
          'amt': 'Amount',
          'priceAmt': 'Price Amount',
          'billAmt': 'Bill Amount (discount\n& additional charged)',
          'paid': 'Paid',
          'payMethod': 'Payment Method',
          'cash': 'Cash',
          'cred': 'Credit',
          'due': 'Due Amount',
          'note': 'Note',
        };
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, 0), Offset(min(x + dash, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
