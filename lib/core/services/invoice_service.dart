import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../features/sales/domain/sale.dart';

class InvoiceService {
  static Future<Uint8List> generateSaleReceipt(Sale sale) async {
    final pdf = pw.Document();

    // Load Bengali font
    final fontData = await rootBundle.load("assets/fonts/HindSiliguri-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);


    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Dynamic height for receipt printers
        theme: pw.ThemeData.withFont(base: ttf),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('আমার দোকান', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('আপনার বিশ্বস্ত কেনাকাটার সঙ্গী', style: pw.TextStyle(fontSize: 10)),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('ইনভয়েস নং: ${sale.invoiceId}'),
              pw.Text('তারিখ: ${DateFormat('dd/MM/yyyy hh:mm a').format(sale.saleDate)}'),
              if (sale.customerName != null) pw.Text('ক্রেতা: ${sale.customerName}'),
              pw.Divider(),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('বিবরণ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('পরিমাণ', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('মূল্য', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('মোট', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  ...sale.items.map((item) => pw.TableRow(
                    children: [
                      pw.Text(item.productName),
                      pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.right),
                      pw.Text(item.unitPrice.toStringAsFixed(2), textAlign: pw.TextAlign.right),
                      pw.Text(item.subTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right),
                    ],
                  )),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('মোট পরিমাণ:'),
                  pw.Text('${sale.totalAmount + sale.discount}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (sale.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ডিসকাউন্ট:'),
                    pw.Text('-${sale.discount}'),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('সর্বমোট (Net Total):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${sale.totalAmount}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('পরিশোধিত:'),
                  pw.Text('${sale.paidAmount}'),
                ],
              ),
              if (sale.dueAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('বাকি:', style: pw.TextStyle(color: PdfColors.red)),
                    pw.Text('${sale.dueAmount}', style: pw.TextStyle(color: PdfColors.red)),
                  ],
                ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('ধন্যবাদ, আবার আসবেন!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
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
      subject: 'ইনভয়েস: ${sale.invoiceId}',
      text: 'আপনার বিক্রয় রশিদটি সংযুক্ত করা হলো।',
    );
  }
}
