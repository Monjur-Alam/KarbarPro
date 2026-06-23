import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/sales/domain/sale.dart';

class InvoiceService {
  static Future<Uint8List> generateSaleReceipt(Sale sale, {bool isBangla = true}) {
    final html = _buildHtml(sale, isBangla: isBangla);
    return Printing.convertHtml(format: PdfPageFormat.roll80, html: html);
  }

  static String _buildHtml(Sale sale, {required bool isBangla}) {
    final L        = _lbl(isBangla);
    final dateStr  = DateFormat('dd/MM/yyyy hh:mm a').format(sale.saleDate);
    final isCash   = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + sale.discount;

    // ── item rows ───────────────────────────────────────────────────
    final rows = StringBuffer();
    for (final item in sale.items) {
      rows.write('''<tr>
        <td class="tn">${_e(item.productName)}</td>
        <td class="tc">${item.quantity}</td>
        <td class="tr">৳${item.unitPrice.toStringAsFixed(2)}</td>
        <td class="tr b">৳${item.subTotal.toStringAsFixed(2)}</td>
      </tr>''');
    }

    final custRow = sale.customerName != null
        ? '<tr><td class="lbl">${L['cust']}</td><td colspan="2" class="val">${_e(sale.customerName!)}</td></tr>'
        : '';
    final discRow = sale.discount > 0
        ? '<tr><td class="lbl">${L['disc']}</td><td colspan="2" class="val red">−৳${sale.discount.toStringAsFixed(2)}</td></tr>'
        : '';
    final dueRow = sale.dueAmount > 0
        ? '<tr><td class="lbl b red">${L['due']}</td><td colspan="2" class="val b red">৳${sale.dueAmount.toStringAsFixed(2)}</td></tr>'
        : '';

    final payClass = isCash ? 'bcash' : 'bcred';
    final payLabel = isCash ? L['cash']! : L['cred']!;

    return '''<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:sans-serif;font-size:11px;color:#111;max-width:80mm;background:#fff}
  .hdr{text-align:center;padding:12px 6px 8px;border-bottom:2px solid #111}
  .sn{font-size:20px;font-weight:700;margin-bottom:2px}
  .tl{font-size:9px;color:#666}
  .meta{padding:6px;border-bottom:1px dashed #bbb}
  .meta table{width:100%}
  .lbl{color:#777;font-size:9.5px;width:42%}
  .val{font-weight:700;font-size:9.5px}
  .badge{display:inline-block;padding:1px 7px;border-radius:3px;font-size:9px;font-weight:700}
  .bcash{background:#e8f5e9;color:#2e7d32;border:1px solid #a5d6a7}
  .bcred{background:#fff3e0;color:#e65100;border:1px solid #ffcc80}
  .itbl{width:100%;border-collapse:collapse;border-bottom:1px dashed #bbb}
  .itbl thead tr{background:#f5f5f5;border-top:1px solid #ddd;border-bottom:1px solid #ddd}
  .itbl th{padding:4px 5px;font-size:9px;font-weight:700;color:#555;text-transform:uppercase}
  .itbl td{padding:5px 5px;font-size:10.5px;vertical-align:top;border-bottom:1px dotted #ddd}
  .itbl tr:last-child td{border-bottom:none}
  .tn{max-width:32mm;word-break:break-word}
  .tc{text-align:center}
  .tr{text-align:right}
  .sum{padding:6px;border-top:2px solid #111}
  .sum table{width:100%}
  .sum .lbl{color:#444;font-size:10.5px}
  .sum .val{text-align:right;font-size:10.5px}
  .tot td{font-size:13px!important;font-weight:700!important;padding:5px 0!important;
          border-top:1px solid #333;border-bottom:1px solid #333}
  .ftr{text-align:center;padding:8px 6px 12px;border-top:1px dashed #bbb}
  .ty{font-size:11px;font-weight:700}
  .pw{font-size:8px;color:#bbb;margin-top:3px}
  .b{font-weight:700}
  .red{color:#c62828}
</style></head><body>

<div class="hdr">
  <div class="sn">${L['shop']}</div>
  <div class="tl">${L['tag']}</div>
</div>

<div class="meta"><table>
  <tr><td class="lbl">${L['inv']}</td><td class="val">${_e(sale.invoiceId)}</td></tr>
  <tr><td class="lbl">${L['date']}</td><td class="val">$dateStr</td></tr>
  $custRow
  <tr><td class="lbl">${L['pay']}</td><td class="val"><span class="badge $payClass">$payLabel</span></td></tr>
</table></div>

<table class="itbl">
  <thead><tr>
    <th style="text-align:left">${L['prod']}</th>
    <th class="tc">${L['qty']}</th>
    <th class="tr">${L['rate']}</th>
    <th class="tr">${L['amt']}</th>
  </tr></thead>
  <tbody>$rows</tbody>
</table>

<div class="sum"><table>
  <tr><td class="lbl">${L['sub']}</td><td class="val">৳${subtotal.toStringAsFixed(2)}</td></tr>
  $discRow
  <tr class="tot"><td class="lbl">${L['net']}</td><td class="val">৳${sale.totalAmount.toStringAsFixed(2)}</td></tr>
  <tr><td class="lbl">${L['paid']}</td><td class="val">৳${sale.paidAmount.toStringAsFixed(2)}</td></tr>
  $dueRow
</table></div>

<div class="ftr">
  <div class="ty">${L['ty']}</div>
  <div class="pw">${L['pw']}</div>
</div>

</body></html>''';
  }

  static Map<String, String> _lbl(bool bn) => bn
      ? {
          'shop': 'আমার দোকান',
          'tag' : 'আপনার বিশ্বস্ত কেনাকাটার সঙ্গী',
          'inv' : 'ইনভয়েস নং',
          'date': 'তারিখ',
          'cust': 'ক্রেতা',
          'pay' : 'পেমেন্ট',
          'cash': 'নগদ',
          'cred': 'বাকি',
          'prod': 'পণ্য',
          'qty' : 'পরিমাণ',
          'rate': 'দর',
          'amt' : 'মোট',
          'sub' : 'উপমোট',
          'disc': 'ছাড়',
          'net' : 'সর্বমোট',
          'paid': 'পরিশোধিত',
          'due' : 'বাকি',
          'ty'  : 'ধন্যবাদ! আবার আসবেন।',
          'pw'  : 'Powered by আমার দোকান',
        }
      : {
          'shop': 'Amar Dokan',
          'tag' : 'Your trusted shopping partner',
          'inv' : 'Invoice No',
          'date': 'Date',
          'cust': 'Customer',
          'pay' : 'Payment',
          'cash': 'Cash',
          'cred': 'Credit',
          'prod': 'Product',
          'qty' : 'Qty',
          'rate': 'Rate',
          'amt' : 'Amount',
          'sub' : 'Subtotal',
          'disc': 'Discount',
          'net' : 'Net Total',
          'paid': 'Paid',
          'due' : 'Due',
          'ty'  : 'Thank you! Come again.',
          'pw'  : 'Powered by Amar Dokan',
        };

  static String _e(String t) =>
      t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static Future<void> printReceipt(Sale sale, {bool isBangla = true}) async {
    final pdf = await generateSaleReceipt(sale, isBangla: isBangla);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'Receipt_${sale.invoiceId}',
    );
  }

  static Future<void> shareReceipt(Sale sale, {bool isBangla = true}) async {
    final pdf = await generateSaleReceipt(sale, isBangla: isBangla);
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/Receipt_${sale.invoiceId}.pdf');
    await file.writeAsBytes(pdf);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: isBangla ? 'ইনভয়েস: ${sale.invoiceId}' : 'Invoice: ${sale.invoiceId}',
    );
  }
}
