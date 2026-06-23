import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/sales/domain/sale.dart';

class InvoiceService {
  static Future<Uint8List> generateSaleReceipt(
    Sale sale, {
    bool isBangla = true,
    int copies = 1,
    String shopName = 'আমার দোকান',
    String shopAddress = '',
    String shopPhone = '',
  }) async {
    final html = _buildHtml(
      sale,
      isBangla: isBangla,
      copies: copies,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
    );
    // convertHtml uses the device WebView which handles Bengali complex-script
    // rendering correctly. pw widgets do not apply OpenType shaping for Bengali.
    // ignore: deprecated_member_use
    return Printing.convertHtml(format: PdfPageFormat.roll80, html: html);
  }

  static String _buildHtml(
    Sale sale, {
    required bool isBangla,
    int copies = 1,
    String shopName = 'আমার দোকান',
    String shopAddress = '',
    String shopPhone = '',
  }) {
    final L = _lbl(isBangla);
    final dateStr = DateFormat('dd/MM/yyyy').format(sale.saleDate);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + sale.discount;

    // ── Item rows ──────────────────────────────────────────────
    final rows = StringBuffer();
    int idx = 1;
    for (final item in sale.items) {
      rows.write('''
        <tr>
          <td class="num">$idx</td>
          <td class="name">${_e(item.productName)}</td>
          <td class="money">৳${item.unitPrice.toStringAsFixed(2)}</td>
          <td class="center">${item.quantity}</td>
          <td class="money b">৳${item.subTotal.toStringAsFixed(2)}</td>
        </tr>
        <tr class="sep-row"><td colspan="5"><div class="dotted"></div></td></tr>''');
      idx++;
    }

    final custRow = sale.customerName != null
        ? '<tr class="meta-row"><td class="ml">${L['cust']}</td>'
          '<td class="mv">${_e(sale.customerName!)}</td></tr>'
          '<tr><td colspan="2"><div class="dotted"></div></td></tr>'
        : '';

    final dueSection = sale.dueAmount > 0
        ? '<div class="dotted"></div>'
          '<div class="sum-row"><span class="sl red b">${L['due']}</span>'
          '<span class="sv red b">৳${sale.dueAmount.toStringAsFixed(2)}</span></div>'
        : '';

    final noteSection = (sale.notes != null && sale.notes!.isNotEmpty)
        ? '<div class="dotted" style="margin-top:8px"></div>'
          '<div class="sum-row" style="align-items:flex-start">'
          '<span class="sl">${L['note']}</span>'
          '<span class="sv" style="text-align:right;max-width:55%">${_e(sale.notes!)}</span></div>'
        : '';

    final addrLine = shopAddress.isNotEmpty ? '<div class="sub">${_e(shopAddress)}</div>' : '';
    final phoneLine = shopPhone.isNotEmpty ? '<div class="sub">${_e(shopPhone)}</div>' : '';
    final payLabel = isCash ? L['cash']! : L['cred']!;

    // SVG store icon (grey outline)
    const storeIcon =
        '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" '
        'xmlns="http://www.w3.org/2000/svg" style="display:block;margin:0 auto 6px">'
        '<path d="M3 9l1-5h16l1 5" stroke="#aaa" stroke-width="1.5" stroke-linecap="round"/>'
        '<path d="M3 9v11a1 1 0 001 1h6v-5h4v5h6a1 1 0 001-1V9" stroke="#aaa" stroke-width="1.5"/>'
        '<path d="M3 9c0 1.66 1.34 3 3 3s3-1.34 3-3" stroke="#aaa" stroke-width="1.5"/>'
        '<path d="M9 9c0 1.66 1.34 3 3 3s3-1.34 3-3" stroke="#aaa" stroke-width="1.5"/>'
        '<path d="M15 9c0 1.66 1.34 3 3 3s3-1.34 3-3" stroke="#aaa" stroke-width="1.5"/>'
        '</svg>';

    final block = '''
<div class="receipt">
  <div class="hdr">
    $storeIcon
    <div class="sn">${_e(shopName)}</div>
    $addrLine
    $phoneLine
    <div class="title">${L['title']}</div>
  </div>

  <div class="dotted"></div>

  <table class="mt">
    <tr class="meta-row"><td class="ml">${L['inv']}</td><td class="mv">${_e(sale.invoiceId)}</td></tr>
    <tr><td colspan="2"><div class="dotted"></div></td></tr>
    <tr class="meta-row"><td class="ml">${L['date']}</td><td class="mv">$dateStr</td></tr>
    <tr><td colspan="2"><div class="dotted"></div></td></tr>
    $custRow
  </table>

  <table class="itable">
    <thead>
      <tr>
        <th class="num">#</th>
        <th class="left">${L['prod']}</th>
        <th class="right">${L['rate']}</th>
        <th class="center">${L['qty']}</th>
        <th class="right">${L['amt']}</th>
      </tr>
      <tr><td colspan="5"><div class="dotted"></div></td></tr>
    </thead>
    <tbody>$rows</tbody>
  </table>

  <div class="sum-block">
    <div class="sum-row">
      <span class="sl">${L['priceAmt']}</span>
      <span class="sv">৳${subtotal.toStringAsFixed(2)}</span>
    </div>
    <div class="spacer"></div>
    <div class="sum-row">
      <span class="sl">${L['billAmt']}</span>
      <span class="sv">৳${sale.totalAmount.toStringAsFixed(2)}</span>
    </div>
    <div class="spacer"></div>
    <div class="sum-row">
      <span class="sl">${L['paid']}</span>
      <span class="sv">৳${sale.paidAmount.toStringAsFixed(2)}</span>
    </div>
    <div class="dotted" style="margin:8px 0 0"></div>
    <div class="sum-row" style="padding-top:6px">
      <span class="sl">${L['payMethod']}</span>
      <span class="sv">$payLabel</span>
    </div>
    $dueSection
    $noteSection
  </div>
</div>''';

    final allCopies = List.filled(copies, block).join('<div class="copy-sep"></div>');

    // No base64 font embedding — system Bengali font (Noto Sans Bengali on Android,
    // Kohinoor Bangla on iOS) handles complex-script shaping inside the WebView.
    return '''<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{
  font-family:'Noto Sans Bengali','Hind Siliguri','Kohinoor Bangla',
              'Noto Sans',Arial,sans-serif;
  font-size:12px;color:#111;width:100%;background:#fff;
  -webkit-print-color-adjust:exact;print-color-adjust:exact
}

.copy-sep{width:100%;border-top:2px dashed #999;margin:10px 0}
.receipt{width:100%;padding:8px 5px}

.hdr{text-align:center;padding:8px 0 6px}
.sn{font-size:22px;font-weight:700;margin-bottom:2px}
.sub{font-size:12px;color:#444;margin-top:1px}
.title{font-size:17px;font-weight:700;margin-top:6px;margin-bottom:4px}

.dotted{border:none;border-top:1px dashed #aaa;margin:0}

.mt{width:100%;border-collapse:collapse}
.meta-row td{padding:7px 0}
.ml{font-size:12px;color:#333;width:44%}
.mv{font-size:12px;font-weight:700;text-align:right}

.itable{width:100%;border-collapse:collapse;margin-top:4px}
.itable thead th{font-size:10px;font-weight:700;color:#555;padding:5px 2px;text-transform:uppercase}
.sep-row td{padding:0}
.itable tbody td{font-size:12px;padding:7px 2px;vertical-align:top}
.num{width:18px;text-align:center}
.name{word-break:break-word}
.money{text-align:right;white-space:nowrap;width:52px}
.center{text-align:center;width:30px}
.left{text-align:left}
.right{text-align:right}
.b{font-weight:700}

.sum-block{padding:4px 0}
.sum-row{display:flex;justify-content:space-between;align-items:flex-start;padding:6px 0 0}
.sl{font-size:13px;color:#333;max-width:58%}
.sv{font-size:13px;text-align:right}
.spacer{height:4px}
.red{color:#c62828}
</style></head>
<body>$allCopies</body></html>''';
  }

  static Map<String, String> _lbl(bool bn) => bn
      ? {
          'title': 'বিক্রয় চালান',
          'inv': 'ইনভয়েস নং:',
          'date': 'তারিখ:',
          'cust': 'ক্রেতার নাম:',
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
          'note': 'নোট:',
        }
      : {
          'title': 'Sales Invoice',
          'inv': 'Invoice No:',
          'date': 'Date:',
          'cust': 'Customer Name:',
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
          'note': 'Note:',
        };

  static String _e(String t) =>
      t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static Future<void> printReceipt(
    Sale sale, {
    bool isBangla = true,
    int copies = 1,
    String shopName = 'আমার দোকান',
    String shopAddress = '',
    String shopPhone = '',
  }) async {
    final pdf = await generateSaleReceipt(
      sale,
      isBangla: isBangla,
      copies: copies,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'Receipt_${sale.invoiceId}',
    );
  }

  static Future<void> shareReceipt(
    Sale sale, {
    bool isBangla = true,
    String shopName = 'আমার দোকান',
    String shopAddress = '',
    String shopPhone = '',
  }) async {
    final pdf = await generateSaleReceipt(
      sale,
      isBangla: isBangla,
      copies: 1,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Receipt_${sale.invoiceId}.pdf');
    await file.writeAsBytes(pdf);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: isBangla ? 'ইনভয়েস: ${sale.invoiceId}' : 'Invoice: ${sale.invoiceId}',
    ));
  }
}
