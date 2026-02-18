import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../features/sales/domain/sale.dart';

class InvoiceService {
  static String _escapeHtml(String text) {
    return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }

  static String _buildReceiptHtml(Sale sale) {
    final html = StringBuffer('''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Hind+Siliguri:wght@400;700&display=swap');
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Hind Siliguri', sans-serif; padding: 12px; font-size: 11px; color: #222; max-width: 80mm; }
  .center { text-align: center; }
  .shop-name { font-size: 18px; font-weight: 700; }
  .tagline { font-size: 9px; color: #666; }
  hr { border: none; border-top: 1px dashed #999; margin: 6px 0; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 3px 4px; text-align: left; font-size: 10px; }
  th { border-bottom: 1px solid #999; font-weight: 700; }
  .text-right { text-align: right; }
  .row { display: flex; justify-content: space-between; margin: 2px 0; }
  .bold { font-weight: 700; }
  .total-row { font-size: 13px; font-weight: 700; margin: 4px 0; }
  .text-red { color: #c62828; }
  .thanks { font-style: italic; font-size: 10px; color: #555; margin-top: 12px; }
</style>
</head>
<body>
''');

    html.writeln('<div class="center">');
    html.writeln('<div class="shop-name">আমার দোকান</div>');
    html.writeln('<div class="tagline">আপনার বিশ্বস্ত কেনাকাটার সঙ্গী</div>');
    html.writeln('</div>');
    html.writeln('<hr>');

    html.writeln('<div class="row"><span>ইনভয়েস নং: ${_escapeHtml(sale.invoiceId)}</span></div>');
    html.writeln('<div class="row"><span>তারিখ: ${DateFormat('dd/MM/yyyy hh:mm a').format(sale.saleDate)}</span></div>');
    if (sale.customerName != null) {
      html.writeln('<div class="row"><span>ক্রেতা: ${_escapeHtml(sale.customerName!)}</span></div>');
    }
    html.writeln('<hr>');

    // Items table
    html.writeln('<table>');
    html.writeln('<tr><th>বিবরণ</th><th class="text-right">পরিমাণ</th><th class="text-right">মূল্য</th><th class="text-right">মোট</th></tr>');
    for (final item in sale.items) {
      html.writeln('<tr>');
      html.writeln('<td>${_escapeHtml(item.productName)}</td>');
      html.writeln('<td class="text-right">${item.quantity}</td>');
      html.writeln('<td class="text-right">${item.unitPrice.toStringAsFixed(2)}</td>');
      html.writeln('<td class="text-right">${item.subTotal.toStringAsFixed(2)}</td>');
      html.writeln('</tr>');
    }
    html.writeln('</table>');
    html.writeln('<hr>');

    html.writeln('<div class="row"><span>মোট পরিমাণ:</span><span class="bold">${(sale.totalAmount + sale.discount).toStringAsFixed(2)}</span></div>');
    if (sale.discount > 0) {
      html.writeln('<div class="row"><span>ডিসকাউন্ট:</span><span>-${sale.discount.toStringAsFixed(2)}</span></div>');
    }
    html.writeln('<div class="row total-row"><span>সর্বমোট (Net Total):</span><span>${sale.totalAmount.toStringAsFixed(2)}</span></div>');
    html.writeln('<div class="row"><span>পরিশোধিত:</span><span>${sale.paidAmount.toStringAsFixed(2)}</span></div>');
    if (sale.dueAmount > 0) {
      html.writeln('<div class="row text-red"><span>বাকি:</span><span>${sale.dueAmount.toStringAsFixed(2)}</span></div>');
    }

    html.writeln('<div class="center thanks">ধন্যবাদ, আবার আসবেন!</div>');
    html.writeln('</body></html>');

    return html.toString();
  }

  static Future<Uint8List> generateSaleReceipt(Sale sale) async {
    final htmlContent = _buildReceiptHtml(sale);
    return Printing.convertHtml(
      format: PdfPageFormat.roll80,
      html: htmlContent,
    );
  }

  static Future<void> printReceipt(Sale sale) async {
    final pdfBytes = await generateSaleReceipt(sale);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${sale.invoiceId}',
    );
  }

  static Future<void> shareReceipt(Sale sale) async {
    final pdfBytes = await generateSaleReceipt(sale);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Receipt_${sale.invoiceId}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ইনভয়েস: ${sale.invoiceId}',
    );
  }
}
