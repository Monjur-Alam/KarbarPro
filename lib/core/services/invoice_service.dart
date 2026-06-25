import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/sales/domain/sale.dart';
import '../settings/app_settings_cubit.dart';

class InvoiceService {
  static const String _storeIconSvg =
      '<svg width="40" height="40" viewBox="0 0 24 24" fill="none" '
      'xmlns="http://www.w3.org/2000/svg" style="display:block;margin:0 auto 4px">'
      '<path d="M3 9l1-5h16l1 5" stroke="#10B981" stroke-width="1.5" stroke-linecap="round"/>'
      '<path d="M3 9v11a1 1 0 001 1h6v-5h4v5h6a1 1 0 001-1V9" stroke="#10B981" stroke-width="1.5"/>'
      '<path d="M3 9c0 1.66 1.34 3 3 3s3-1.34 3-3" stroke="#10B981" stroke-width="1.5"/>'
      '<path d="M9 9c0 1.66 1.34 3 3 3s3-1.34 3-3" stroke="#10B981" stroke-width="1.5"/>'
      '<path d="M15 9c0 1.66 1.34 3 3 3s3-1.34 3-3" stroke="#10B981" stroke-width="1.5"/>'
      '</svg>';

  // ── Public API ────────────────────────────────────────────

  static Future<Uint8List> generateSaleReceipt(
    Sale sale,
    AppSettingsState settings, {
    int copies = 1,
  }) async {
    final html = _buildFullHtml(sale, settings, copies: copies);
    final isA4 = settings.receiptTemplate == 6;
    // convertHtml uses the device WebView which handles Bengali complex-script
    // rendering correctly. pw widgets do not apply OpenType shaping for Bengali.
    // ignore: deprecated_member_use
    return Printing.convertHtml(
      format: isA4 ? PdfPageFormat.a4 : PdfPageFormat.roll80,
      html: html,
    );
  }

  static Future<void> printReceipt(
    Sale sale,
    AppSettingsState settings, {
    int copies = 1,
  }) async {
    final pdf = await generateSaleReceipt(sale, settings, copies: copies);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'Receipt_${sale.invoiceId}',
    );
  }

  static Future<void> shareReceipt(
    Sale sale,
    AppSettingsState settings,
  ) async {
    final pdf = await generateSaleReceipt(sale, settings, copies: 1);
    final dir = await getTemporaryDirectory();
    
    // Rasterize the first page of the PDF to a PNG image
    final pages = await Printing.raster(pdf, pages: [0], dpi: 200).toList();
    if (pages.isNotEmpty) {
      final imageBytes = await pages.first.toPng();
      final file = File('${dir.path}/Receipt_${sale.invoiceId}.png');
      await file.writeAsBytes(imageBytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: settings.isBangla
            ? 'ইনভয়েস: ${sale.invoiceId}'
            : 'Invoice: ${sale.invoiceId}',
      ));
    }
  }

  // ── HTML assembly ─────────────────────────────────────────

  static String _buildFullHtml(
    Sale sale,
    AppSettingsState settings, {
    int copies = 1,
  }) {
    final block = _buildBlock(sale, settings);
    final allCopies =
        List.filled(copies, block).join('<div class="copy-sep"></div>');
    return '<!DOCTYPE html><html><head><meta charset="UTF-8">'
        '<style>${_baseCss(settings)}</style>'
        '</head><body>$allCopies</body></html>';
  }

  static String _buildBlock(Sale sale, AppSettingsState settings) {
    switch (settings.receiptTemplate) {
      case 1:
        return _buildDetailedPos(sale, settings);
      case 2:
        return _buildBigFont(sale, settings);
      case 3:
        return _buildWithQr(sale, settings);
      case 4:
        return _buildWithBarcode(sale, settings);
      case 5:
        return _buildTicket(sale, settings);
      case 6:
        return _buildA4Style1(sale, settings);
      default:
        return _buildStandard(sale, settings);
    }
  }

  // ── Shared CSS ────────────────────────────────────────────

  static String _baseCss(AppSettingsState s) {
    final fs = 10 + (s.printFontSize * 4).round();
    final lh = (1.3 + s.printLineHeight * 0.6).toStringAsFixed(2);
    return '''
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Noto Sans Bengali','Hind Siliguri','Kohinoor Bangla',
  'Noto Sans',Arial,sans-serif;
  font-size:${fs}px;color:#111;width:100%;background:#fff;
  line-height:$lh;
  -webkit-print-color-adjust:exact;print-color-adjust:exact}
.copy-sep{width:100%;border-top:2px dashed #999;margin:12px 0}
.receipt{width:100%;padding:8px 5px}
.hdr{text-align:center;padding:8px 0 6px}
.sn{font-size:${fs + 10}px;font-weight:700;margin-bottom:2px}
.sub{font-size:${fs - 1}px;color:#222;margin-top:1px}
.title{font-size:${fs + 5}px;font-weight:700;margin-top:6px;margin-bottom:4px}
.dotted{border:none;border-top:1px dashed #bbb;margin:2px 0}
.solid{border:none;border-top:1px solid #222;margin:2px 0}
.mt{width:100%;border-collapse:collapse}
.meta-row td{padding:5px 0}
.ml{font-size:${fs}px;width:44%}
.mv{font-size:${fs}px;font-weight:700;text-align:right}
.itable{width:100%;border-collapse:collapse;margin-top:4px}
.itable thead th{font-size:${fs - 2}px;font-weight:700;
  padding:4px 2px;text-transform:uppercase}
.sep-row td{padding:0}
.itable tbody td{font-size:${fs}px;padding:5px 2px;vertical-align:top}
.num{width:18px;text-align:center}
.name{word-break:break-word}
.money{text-align:right;white-space:nowrap;width:52px}
.center{text-align:center;width:30px}
.left{text-align:left}
.right{text-align:right}
.b{font-weight:700}
.sum-block{padding:4px 0}
.sum-row{display:flex;justify-content:space-between;
  align-items:flex-start;padding:5px 0 0}
.sl{font-size:${fs + 1}px;max-width:58%}
.sv{font-size:${fs + 1}px;text-align:right}
.spacer{height:3px}
.red{color:#c62828}
.footer{text-align:center;margin-top:10px;font-size:${fs - 1}px;color:#333}
''';
  }

  // ── Template 0: Standard ─────────────────────────────────

  static String _buildStandard(Sale sale, AppSettingsState s) {
    final L = _lbl(s.isBangla);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + s.discount(sale);

    final rows = StringBuffer();
    final items = _sortedItems(sale, s);
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      rows.write('''
<tr>
  <td class="num">${i + 1}</td>
  <td class="name">${_e(it.productName)}</td>
  <td class="money">৳${it.unitPrice.toStringAsFixed(2)}</td>
  <td class="center">${it.quantity}</td>
  <td class="money b">৳${it.subTotal.toStringAsFixed(2)}</td>
</tr>
<tr class="sep-row"><td colspan="5"><div class="dotted"></div></td></tr>''');
    }

    final custRow = (s.printCustomerInfo && sale.customerName != null)
        ? '<tr class="meta-row"><td class="ml">${L['cust']}</td>'
            '<td class="mv">${_e(sale.customerName!)}</td></tr>'
            '<tr><td colspan="2"><div class="dotted"></div></td></tr>'
        : '';

    return '''<div class="receipt">
<div class="hdr">
  $_storeIconSvg
  <div class="sn">${_e(s.shopName)}</div>
  ${s.shopAddress.isNotEmpty ? '<div class="sub">${_e(s.shopAddress)}</div>' : ''}
  ${s.shopPhone.isNotEmpty ? '<div class="sub">${_e(s.shopPhone)}</div>' : ''}
  <div class="title">${_e(s.receiptTitle)}</div>
</div>
<div class="dotted"></div>
<table class="mt">
  <tr class="meta-row">
    <td class="ml">${L['inv']}</td>
    <td class="mv">${s.invoiceIdPrefix}${_e(sale.invoiceId)}</td>
  </tr>
  <tr><td colspan="2"><div class="dotted"></div></td></tr>
  <tr class="meta-row">
    <td class="ml">${L['date']}</td>
    <td class="mv">$dateStr</td>
  </tr>
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
  <div class="dotted" style="margin:6px 0 0"></div>
  <div class="sum-row" style="padding-top:5px">
    <span class="sl">${L['payMethod']}</span>
    <span class="sv">${isCash ? L['cash']! : L['cred']!}</span>
  </div>
  ${sale.dueAmount > 0 ? '<div class="dotted"></div><div class="sum-row"><span class="sl red b">${L['due']}</span><span class="sv red b">৳${sale.dueAmount.toStringAsFixed(2)}</span></div>' : ''}
  ${(sale.notes != null && sale.notes!.isNotEmpty) ? '<div class="dotted"></div><div class="sum-row"><span class="sl">${L['note']}</span><span class="sv">${_e(sale.notes!)}</span></div>' : ''}
  ${s.receiptFooter.isNotEmpty ? '<div class="footer">${_e(s.receiptFooter)}</div>' : ''}
</div>
</div>''';
  }

  // ── Template 1: Detailed POS ─────────────────────────────

  static String _buildDetailedPos(Sale sale, AppSettingsState s) {
    final isBn = s.isBangla;
    final L = _lbl(isBn);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + s.discount(sale);
    final bdr = s.enableTableBorder ? '1px solid #333' : 'none';

    final items = _sortedItems(sale, s);
    final rows = StringBuffer();
    for (final it in items) {
      rows.write('''
<tr>
  <td style="border:$bdr;padding:4px">${_e(it.productName)}</td>
  <td style="border:$bdr;padding:4px;text-align:right">৳${it.unitPrice.toStringAsFixed(2)}</td>
  <td style="border:$bdr;padding:4px;text-align:center">0.00</td>
  <td style="border:$bdr;padding:4px;text-align:right;font-weight:700">৳${it.subTotal.toStringAsFixed(2)}</td>
</tr>
<tr>
  <td style="border:$bdr;padding:2px 4px 4px;font-size:10px">${it.quantity}</td>
  <td colspan="3" style="border:$bdr;padding:2px 4px 4px"></td>
</tr>''');
    }

    final totalQty =
        sale.items.fold<int>(0, (sum, it) => sum + it.quantity);
    final paymentTable = s.enablePaymentInfo
        ? '''<p style="font-weight:700;margin:8px 0 4px">${isBn ? 'পেমেন্ট তথ্য' : 'Payment Information'}</p>
<table style="width:100%;border-collapse:collapse;font-size:11px">
  <tr>
    <td style="border:$bdr;padding:3px;font-weight:700">${isBn ? 'তারিখ' : 'Date'}</td>
    <td style="border:$bdr;padding:3px;font-weight:700">${isBn ? 'পরিশোধ' : 'Paid'}</td>
    <td style="border:$bdr;padding:3px;font-weight:700">${isBn ? 'বাকি' : 'Due'}</td>
  </tr>
  <tr>
    <td style="border:$bdr;padding:3px">${DateFormat('dd-MM-yyyy').format(sale.saleDate)}</td>
    <td style="border:$bdr;padding:3px">৳${sale.paidAmount.toStringAsFixed(2)}(${isCash ? (isBn ? 'নগদ' : 'CASH') : (isBn ? 'বাকি' : 'CREDIT')})</td>
    <td style="border:$bdr;padding:3px">৳${sale.dueAmount.toStringAsFixed(2)}</td>
  </tr>
</table>'''
        : '';

    final custLine = (s.printCustomerInfo && sale.customerName != null)
        ? '<tr><td colspan="2" style="padding:3px">${isBn ? 'ক্রেতা' : 'Customer'}: <b>${_e(sale.customerName!)}</b></td></tr>'
        : '';

    return '''<div class="receipt">
<div class="hdr">
  <div class="sn" style="font-size:18px">${_e(s.shopName)}</div>
  ${s.shopAddress.isNotEmpty ? '<div class="sub">${_e(s.shopAddress)}</div>' : ''}
  ${s.shopPhone.isNotEmpty ? '<div class="sub">${_e(s.shopPhone)}</div>' : ''}
</div>
<div class="solid"></div>
<p style="font-size:11px;margin:4px 0">
  ${isBn ? 'ইনভয়েস নং' : 'Inv No'}${s.invoiceIdPrefix}${_e(sale.invoiceId)}&nbsp;&nbsp;
  ${isBn ? 'তারিখ' : 'Date'}:$dateStr&nbsp;&nbsp;
  ${isBn ? 'পেমেন্ট' : 'Payment Method'}:${isCash ? (isBn ? 'নগদ' : 'CASH RECEIVED') : (isBn ? 'বাকি' : 'CREDIT')}
</p>
<table style="width:100%;border-collapse:collapse;font-size:11px;margin-top:4px">
  <thead>
    <tr>
      <th style="border:$bdr;padding:4px;text-align:left">${isBn ? 'পণ্যের নাম' : 'Item Description'}</th>
      <th style="border:$bdr;padding:4px;text-align:right">${L['rate']}</th>
      <th style="border:$bdr;padding:4px;text-align:center">${isBn ? 'ছাড়' : 'Disc'}</th>
      <th style="border:$bdr;padding:4px;text-align:right">${isBn ? 'মোট' : 'Unit Amt'}</th>
    </tr>
  </thead>
  <tbody>$rows</tbody>
  <tr>
    <td colspan="2" style="border:$bdr;padding:4px;font-size:10px">
      ${isBn ? 'মোট পরিমাণ' : 'Total Qty'}: $totalQty
    </td>
    <td colspan="2" style="border:$bdr;padding:4px;font-size:10px;text-align:right">
      ${isBn ? 'মোট পণ্য' : 'Total Items'}: ${sale.items.length}
    </td>
  </tr>
</table>
<table style="width:100%;border-collapse:collapse;margin-top:4px;font-size:12px">
  $custLine
  <tr>
    <td style="padding:3px">${isBn ? 'মোট' : 'Sub Total'}</td>
    <td style="padding:3px;text-align:right;font-weight:700">৳${subtotal.toStringAsFixed(2)}</td>
  </tr>
  <tr>
    <td style="padding:3px;font-weight:700">${isBn ? 'সর্বমোট' : 'Grand Total'}</td>
    <td style="padding:3px;text-align:right;font-weight:700">৳${sale.totalAmount.toStringAsFixed(2)}</td>
  </tr>
  <tr>
    <td style="padding:3px">${s.customPayableLabel}</td>
    <td style="padding:3px;text-align:right;font-weight:700">৳${sale.paidAmount.toStringAsFixed(2)}</td>
  </tr>
</table>
$paymentTable
${(sale.notes != null && sale.notes!.isNotEmpty) ? '<p style="margin-top:6px;font-size:11px">${_e(sale.notes!)}</p>' : ''}
${s.receiptFooter.isNotEmpty ? '<div class="footer">${_e(s.receiptFooter)}</div>' : ''}
</div>''';
  }

  // ── Template 2: Big Font ──────────────────────────────────

  static String _buildBigFont(Sale sale, AppSettingsState s) {
    final isBn = s.isBangla;
    final L = _lbl(isBn);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + s.discount(sale);

    final items = _sortedItems(sale, s);
    final rows = StringBuffer();
    for (final it in items) {
      rows.write('''
<tr style="border-top:1px solid #ccc">
  <td style="padding:6px 2px;font-size:14px">${_e(it.productName)}</td>
  <td style="padding:6px 2px;text-align:right;font-size:14px;font-weight:700">
    ৳${it.subTotal.toStringAsFixed(2)}
  </td>
</tr>
<tr>
  <td colspan="2" style="padding:0 2px 6px;font-size:12px;color:#444">
    ${it.quantity} X ৳${it.unitPrice.toStringAsFixed(2)}
  </td>
</tr>''');
    }

    final custLine = (s.printCustomerInfo && sale.customerName != null)
        ? '<p style="font-size:13px;margin-bottom:4px">'
            '${isBn ? 'ক্রেতা' : 'Customer'}: <b>${_e(sale.customerName!)}</b></p>'
        : '';

    return '''<div class="receipt">
<div class="hdr">
  <div class="sn" style="font-size:22px">${_e(s.shopName)}</div>
  ${s.shopAddress.isNotEmpty ? '<div class="sub" style="font-size:13px">${_e(s.shopAddress)}</div>' : ''}
  ${s.shopPhone.isNotEmpty ? '<div class="sub" style="font-size:13px">${_e(s.shopPhone)}</div>' : ''}
  <div class="title" style="font-size:16px;margin-top:6px">${_e(s.receiptTitle)}</div>
</div>
<div class="solid"></div>
<p style="font-size:13px;font-weight:700;margin:6px 0 2px">
  ${isBn ? 'বিক্রয় বিবরণ' : 'Invoice Details'}
</p>
<p style="font-size:12px">${isBn ? 'অর্ডার আইডি' : 'Order ID'}:${s.invoiceIdPrefix}${_e(sale.invoiceId)}</p>
<p style="font-size:12px">${isBn ? 'তারিখ' : 'Date'}:$dateStr</p>
<p style="font-size:12px">${isBn ? 'পেমেন্ট পদ্ধতি' : 'Payment Method'}:${isCash ? (isBn ? 'নগদ' : 'Cash') : (isBn ? 'বাকি' : 'Credit')}</p>
$custLine
<div class="solid" style="margin:6px 0"></div>
<table style="width:100%;border-collapse:collapse">
  <thead>
    <tr>
      <th style="text-align:left;font-size:13px;padding:4px 2px">${L['prod']}</th>
      <th style="text-align:right;font-size:13px;padding:4px 2px">${L['amt']}</th>
    </tr>
  </thead>
  <tbody>$rows</tbody>
</table>
<div class="solid" style="margin:4px 0"></div>
<table style="width:100%;border-collapse:collapse">
  <tr>
    <td style="padding:5px 2px;font-size:14px">${isBn ? 'মোট' : 'Sub Total'}</td>
    <td style="text-align:right;padding:5px 2px;font-size:14px;font-weight:700">৳${subtotal.toStringAsFixed(2)}</td>
  </tr>
  <tr>
    <td style="padding:5px 2px;font-size:14px">${s.customPayableLabel}</td>
    <td style="text-align:right;padding:5px 2px;font-size:14px;font-weight:700">৳${sale.totalAmount.toStringAsFixed(2)}</td>
  </tr>
</table>
${sale.dueAmount > 0 ? '<div class="solid" style="margin:4px 0"></div><p style="font-size:14px;color:#c62828;font-weight:700">${isBn ? 'বাকি' : 'Due'}: ৳${sale.dueAmount.toStringAsFixed(2)}</p>' : ''}
${s.receiptFooter.isNotEmpty ? '<div class="footer" style="font-size:14px;margin-top:12px">${_e(s.receiptFooter)}</div>' : ''}
</div>''';
  }

  // ── Template 3: QR Code ───────────────────────────────────

  static String _buildWithQr(Sale sale, AppSettingsState s) {
    final base = _buildStandard(sale, s);
    final qrData = s.qrCodeData.isNotEmpty ? s.qrCodeData : sale.invoiceId;
    final qrSection = '''
<div style="text-align:center;margin:12px 0 8px">
  <svg xmlns="http://www.w3.org/2000/svg" width="90" height="90" viewBox="0 0 21 21"
    style="display:block;margin:0 auto">
    ${_miniQrSvg(qrData)}
  </svg>
  <p style="font-size:9px;margin-top:4px;word-break:break-all;color:#333">$qrData</p>
</div>''';
    return base.replaceFirst('</div>', '$qrSection</div>');
  }

  // ── Template 4: Barcode ───────────────────────────────────

  static String _buildWithBarcode(Sale sale, AppSettingsState s) {
    final base = _buildStandard(sale, s);
    final bars = _barcodeBars(sale.invoiceId);
    final barcodeSection = '''
<div style="text-align:center;margin:12px 0 8px">
  <div style="display:flex;justify-content:center;align-items:flex-end;height:54px;gap:1px">
    $bars
  </div>
  <p style="font-size:9px;letter-spacing:2px;margin-top:4px">${sale.invoiceId}</p>
</div>''';
    return base.replaceFirst('</div>', '$barcodeSection</div>');
  }

  // ── Template 5: Ticket ────────────────────────────────────

  static String _buildTicket(Sale sale, AppSettingsState s) {
    final isBn = s.isBangla;
    final dateStr = _fmtDate(sale.saleDate, true);
    final bdr = '2px solid #333';

    final items = _sortedItems(sale, s);
    final rows = StringBuffer();
    for (final it in items) {
      rows.write('''
<tr>
  <td style="border:$bdr;padding:8px;font-size:14px" colspan="2">${_e(it.productName)}</td>
</tr>
<tr>
  <td style="border:$bdr;padding:8px;font-size:13px">
    ${it.quantity}.0 X ${it.unitPrice.toStringAsFixed(2)}
  </td>
  <td style="border:$bdr;padding:8px;font-size:13px;text-align:right;font-weight:700">
    ${it.subTotal.toStringAsFixed(2)}
  </td>
</tr>''');
    }

    return '''<div class="receipt" style="padding:12px 8px">
<div class="hdr">
  <div style="font-size:28px;font-weight:900;text-align:center;margin-bottom:4px">
    ${_e(s.shopName)}
  </div>
  ${s.shopAddress.isNotEmpty ? '<div style="font-size:13px;text-align:center">${_e(s.shopAddress)}</div>' : ''}
  ${s.shopPhone.isNotEmpty ? '<div style="font-size:13px;text-align:center">${_e(s.shopPhone)}</div>' : ''}
</div>
<div style="text-align:center;font-size:13px;font-weight:700;margin:10px 0">
  ${isBn ? 'টিকেট' : 'Ticket'}:${_e(sale.invoiceId)}&nbsp;&nbsp;${isBn ? 'তারিখ' : 'Date'}:$dateStr
</div>
<table style="width:100%;border-collapse:collapse;border:$bdr">
  $rows
  <tr>
    <td colspan="2" style="border-top:$bdr;padding:10px 8px;text-align:center">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <span style="font-size:16px;font-weight:700">${isBn ? 'টাকা' : 'BDT'}</span>
        <span style="font-size:24px;font-weight:900">৳${sale.totalAmount.toStringAsFixed(2)}</span>
      </div>
    </td>
  </tr>
</table>
${sale.dueAmount > 0 ? '<p style="font-size:13px;color:#c62828;font-weight:700;margin-top:6px">${isBn ? 'বাকি' : 'Due'}: ৳${sale.dueAmount.toStringAsFixed(2)}</p>' : ''}
${s.receiptFooter.isNotEmpty ? '<div class="footer" style="font-size:13px;margin-top:12px">${_e(s.receiptFooter)}</div>' : ''}
</div>''';
  }

  // ── Template 6: A4-Style 1 ────────────────────────────────

  static String _buildA4Style1(Sale sale, AppSettingsState s) {
    final isBn = s.isBangla;
    final L = _lbl(isBn);
    final dateStr = _fmtDate(sale.saleDate, s.showTimeOnReceipt);
    final isCash = sale.paymentMethod == 'cash';
    final subtotal = sale.totalAmount + s.discount(sale);
    const bdr = '1px solid #333';

    final items = _sortedItems(sale, s);
    final rows = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      rows.write('''<tr style="background:${i.isEven ? '#fff' : '#f9f9f9'}">
  <td style="border:$bdr;padding:6px;text-align:center">${i + 1}</td>
  <td style="border:$bdr;padding:6px">${_e(it.productName)}</td>
  <td style="border:$bdr;padding:6px;text-align:right">৳${it.unitPrice.toStringAsFixed(2)}</td>
  <td style="border:$bdr;padding:6px;text-align:center">${it.quantity}</td>
  <td style="border:$bdr;padding:6px;text-align:right;font-weight:700">৳${it.subTotal.toStringAsFixed(2)}</td>
</tr>''');
    }

    final custLine = (s.printCustomerInfo && sale.customerName != null)
        ? '<p style="font-size:13px;margin:3px 0">'
            '${isBn ? 'ক্রেতা' : 'Customer'}: <b>${_e(sale.customerName!)}</b></p>'
        : '';

    return '''<div class="receipt" style="padding:16px">
<div style="text-align:center;margin-bottom:12px">
  <div style="font-size:22px;font-weight:700">${_e(s.shopName)}</div>
  ${s.shopAddress.isNotEmpty ? '<div style="font-size:12px">${_e(s.shopAddress)}</div>' : ''}
  ${s.shopPhone.isNotEmpty ? '<div style="font-size:12px">${_e(s.shopPhone)}</div>' : ''}
</div>
<div style="border-top:2px solid #333;margin:8px 0"></div>
<p style="font-size:14px;font-weight:700;margin-bottom:6px">
  ${isBn ? 'বিক্রয় বিবরণ' : 'Invoice Details'}
</p>
<p style="font-size:12px;margin:2px 0">${isBn ? 'অর্ডার আইডি' : 'Order ID'}:${s.invoiceIdPrefix}${_e(sale.invoiceId)}</p>
<p style="font-size:12px;margin:2px 0">${isBn ? 'তারিখ' : 'Date'}:$dateStr</p>
<p style="font-size:12px;margin:2px 0">${isBn ? 'পেমেন্ট পদ্ধতি' : 'Payment Method'}:${isCash ? (isBn ? 'নগদ' : 'Cash') : (isBn ? 'বাকি' : 'Credit')}</p>
$custLine
<div style="border-top:1px solid #333;margin:8px 0"></div>
<table style="width:100%;border-collapse:collapse">
  <thead>
    <tr style="background:#e8f8f3">
      <th style="border:$bdr;padding:6px;text-align:center;font-size:12px">${isBn ? 'ক্রমিক' : 'SINo'}</th>
      <th style="border:$bdr;padding:6px;text-align:left;font-size:12px">${L['prod']}</th>
      <th style="border:$bdr;padding:6px;text-align:right;font-size:12px">${L['rate']}</th>
      <th style="border:$bdr;padding:6px;text-align:center;font-size:12px">${L['qty']}</th>
      <th style="border:$bdr;padding:6px;text-align:right;font-size:12px">${isBn ? 'মোট' : 'Total'}</th>
    </tr>
  </thead>
  <tbody>$rows</tbody>
</table>
<div style="margin-top:12px">
  <table style="width:50%;margin-left:auto;border-collapse:collapse">
    <tr>
      <td style="padding:4px 6px">${isBn ? 'মোট' : 'Sub Total'}</td>
      <td style="padding:4px 6px;text-align:right">৳${subtotal.toStringAsFixed(2)}</td>
    </tr>
    ${sale.discount > 0 ? '<tr><td style="padding:4px 6px">${isBn ? "ছাড়" : "Discount"}</td><td style="padding:4px 6px;text-align:right;color:#c62828">-৳${sale.discount.toStringAsFixed(2)}</td></tr>' : ''}
    <tr style="border-top:2px solid #333">
      <td style="padding:6px;font-weight:700;font-size:14px">${isBn ? 'সর্বমোট' : 'Grand Total'}</td>
      <td style="padding:6px;text-align:right;font-weight:700;font-size:14px">৳${sale.totalAmount.toStringAsFixed(2)}</td>
    </tr>
    <tr>
      <td style="padding:4px 6px">${L['paid']}</td>
      <td style="padding:4px 6px;text-align:right;color:green">৳${sale.paidAmount.toStringAsFixed(2)}</td>
    </tr>
    ${sale.dueAmount > 0 ? '<tr><td style="padding:4px 6px;color:#c62828;font-weight:700">${isBn ? "বাকি" : "Due"}</td><td style="padding:4px 6px;text-align:right;color:#c62828;font-weight:700">৳${sale.dueAmount.toStringAsFixed(2)}</td></tr>' : ''}
  </table>
</div>
${s.receiptFooter.isNotEmpty ? '<div class="footer" style="margin-top:20px">${_e(s.receiptFooter)}</div>' : ''}
</div>''';
  }

  // ── Helpers ───────────────────────────────────────────────

  static List<SaleItem> _sortedItems(Sale sale, AppSettingsState s) {
    if (s.sortItemsAlphabetical) {
      return List.from(sale.items)
        ..sort((a, b) => a.productName.compareTo(b.productName));
    }
    return sale.items;
  }

  static String _fmtDate(DateTime d, bool showTime) {
    final date = DateFormat('dd/MM/yyyy').format(d);
    return showTime ? '$date ${DateFormat('hh:mm a').format(d)}' : date;
  }

  static String _e(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static Map<String, String> _lbl(bool bn) => bn
      ? {
          'inv': 'ইনভয়েস নং:',
          'date': 'তারিখ:',
          'cust': 'ক্রেতার নাম:',
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
          'note': 'নোট:',
        }
      : {
          'inv': 'Invoice No:',
          'date': 'Date:',
          'cust': 'Customer:',
          'prod': 'Item',
          'qty': 'Qty',
          'rate': 'Price',
          'amt': 'Amt',
          'priceAmt': 'Sub Total',
          'billAmt': 'Grand Total',
          'paid': 'Paid',
          'payMethod': 'Payment Method',
          'cash': 'Cash',
          'cred': 'Credit',
          'due': 'Due',
          'note': 'Note:',
        };

  // Deterministic "barcode" bars from a string seed
  static String _barcodeBars(String seed) {
    final sb = StringBuffer();
    final chars = seed.codeUnits;
    for (int i = 0; i < 32; i++) {
      final c = chars[i % chars.length];
      final w = (c % 3) + 1;
      final h = 30 + (c % 24);
      sb.write('<div style="width:${w}px;height:${h}px;background:#000;'
          'display:inline-block;vertical-align:bottom"></div>');
      if (i % 4 == 3) {
        sb.write('<div style="width:2px;display:inline-block"></div>');
      }
    }
    return sb.toString();
  }

  // Simple fixed-pattern QR-like SVG (decorative — real QR needs qr_flutter)
  static String _miniQrSvg(String data) {
    // 21x21 grid, fixed decorative pattern that looks like a QR finder
    final buf = StringBuffer();
    // Top-left finder
    for (final r in [0, 1, 2, 3, 4, 5, 6]) {
      for (final c in [0, 1, 2, 3, 4, 5, 6]) {
        final fill = (r == 0 || r == 6 || c == 0 || c == 6 ||
                (r >= 2 && r <= 4 && c >= 2 && c <= 4))
            ? '#000'
            : '#fff';
        buf.write('<rect x="$c" y="$r" width="1" height="1" fill="$fill"/>');
      }
    }
    // Top-right finder
    for (final r in [0, 1, 2, 3, 4, 5, 6]) {
      for (final c in [14, 15, 16, 17, 18, 19, 20]) {
        final cc = c - 14;
        final fill = (r == 0 || r == 6 || cc == 0 || cc == 6 ||
                (r >= 2 && r <= 4 && cc >= 2 && cc <= 4))
            ? '#000'
            : '#fff';
        buf.write('<rect x="$c" y="$r" width="1" height="1" fill="$fill"/>');
      }
    }
    // Bottom-left finder
    for (final r in [14, 15, 16, 17, 18, 19, 20]) {
      for (final c in [0, 1, 2, 3, 4, 5, 6]) {
        final rr = r - 14;
        final fill = (rr == 0 || rr == 6 || c == 0 || c == 6 ||
                (rr >= 2 && rr <= 4 && c >= 2 && c <= 4))
            ? '#000'
            : '#fff';
        buf.write('<rect x="$c" y="$r" width="1" height="1" fill="$fill"/>');
      }
    }
    // Data area: pseudo-random from data string
    final codes = data.codeUnits;
    for (int r = 8; r < 14; r++) {
      for (int c = 8; c < 14; c++) {
        final idx = (r * 21 + c) % codes.length;
        if (codes[idx] % 2 == 0) {
          buf.write('<rect x="$c" y="$r" width="1" height="1" fill="#000"/>');
        }
      }
    }
    // Border rect
    buf.write('<rect x="0" y="0" width="21" height="21" '
        'fill="none" stroke="#000" stroke-width="0.5"/>');
    return buf.toString();
  }
}

// Extension for convenience
extension _SettingsExt on AppSettingsState {
  double discount(Sale sale) => sale.discount;
}
