import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../domain/due_ledger_model.dart';
import '../../sales/domain/sale.dart';

class ReportGenerator {
  static Future<void> generateBakirKhataPDF({
    required String shopName,
    required Map<String, dynamic> summary,
    required List<CustomerDue> customers,
    required Map<int, List<CustomerTransaction>> transactionHistories,
  }) async {
    final pdf = pw.Document();
    
    // Load Bangla Font
    final fontData = await rootBundle.load("assets/fonts/HindSiliguri-Regular.ttf");
    final banglaFont = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: banglaFont),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildHeader(shopName, banglaFont),
          pw.SizedBox(height: 20),
          _buildSummarySection(summary, banglaFont),
          pw.SizedBox(height: 20),
          _buildCustomerList(customers, transactionHistories, banglaFont),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Bakir_Khata_Report_${DateFormat('dd_MMM_yyyy').format(DateTime.now())}.pdf',
    );
  }

  static Future<void> generateSalesPDF({
    required String shopName,
    required List<Sale> sales,
    required Map<String, dynamic> summary,
  }) async {
    final pdf = pw.Document();
    
    // Load Bangla Font
    final fontData = await rootBundle.load("assets/fonts/HindSiliguri-Regular.ttf");
    final banglaFont = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: banglaFont),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSalesHeader(shopName, banglaFont),
          pw.SizedBox(height: 20),
          _buildSalesSummarySection(summary, banglaFont),
          pw.SizedBox(height: 20),
          _buildSalesTable(sales, banglaFont),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sales_Report_${DateFormat('dd_MMM_yyyy').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildSalesHeader(String shopName, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(shopName, style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('বিক্রয় বিবরণী রিপোর্ট', style: pw.TextStyle(font: font, fontSize: 18)),
        pw.Text('তারিখ: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 12)),
        pw.Divider(thickness: 1),
      ],
    );
  }

  static pw.Widget _buildSalesSummarySection(Map<String, dynamic> summary, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text('মোট বিক্রি', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('৳${(summary['total'] ?? 0.0).toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Column(
            children: [
              pw.Text('নগদ আদায়', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('৳${(summary['cash'] ?? 0.0).toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
            ],
          ),
          pw.Column(
            children: [
              pw.Text('বাকি বিক্রি', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('৳${(summary['credit'] ?? 0.0).toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSalesTable(List<Sale> sales, pw.Font font) {
    final headers = ['তারিখ', 'ইনভয়েস', 'গ্রাহক', 'ধরণ', 'পরিমাণ'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: sales.map((sale) => [
        DateFormat('dd/MM/yy').format(sale.saleDate),
        sale.invoiceId,
        sale.customerName ?? 'সাধারণ',
        sale.paymentMethod == 'cash' ? 'নগদ' : 'বাকি',
        '৳${sale.totalAmount.toStringAsFixed(0)}',
      ]).toList(),
      headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {4: pw.Alignment.centerRight},
    );
  }

  static pw.Widget _buildHeader(String shopName, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(shopName, style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('বাকির খাতা রিপোর্ট', style: pw.TextStyle(font: font, fontSize: 18)),
        pw.Text('তারিখ: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 12)),
        pw.Divider(thickness: 1),
      ],
    );
  }

  static pw.Widget _buildSummarySection(Map<String, dynamic> summary, pw.Font font) {
    final totalReceivable = summary['totalReceivable'] ?? 0.0;
    final totalCollected = summary['totalCollected'] ?? 0.0;
    final remainingReceivable = totalReceivable; // Based on logic: current balance is what's remaining
    
    final totalPayable = summary['totalPayable'] ?? 0.0;
    final totalPaid = summary['totalPaid'] ?? 0.0;
    final remainingPayable = totalPayable;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('মোট পাবো (বাকি): ৳${totalReceivable.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
                  pw.Text('আদায় হয়েছে: ৳${totalCollected.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('বাকি আছে: ৳${remainingReceivable.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10)),
                ],
              ),
              pw.VerticalDivider(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('মোট দিতে হবে: ৳${totalPayable.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
                  pw.Text('দিয়েছি: ৳${totalPaid.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('বাকি দিতে হবে: ৳${remainingPayable.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomerList(
    List<CustomerDue> customers,
    Map<int, List<CustomerTransaction>> transactionHistories,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('গ্রাহক তালিকা:', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        ...customers.map((customer) {
          final history = transactionHistories[customer.id] ?? [];
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(customer.name, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
                        pw.Text('ফোন: ${customer.phone ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                    pw.Text('৳${customer.currentCreditBalance.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                  ],
                ),
                if (history.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text('লেনদেন ইতিহাস:', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ...history.take(5).map((trans) {
                    final isSale = trans.transactionType == 'sale';
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${DateFormat('dd/MM/yyyy').format(trans.transactionDate)} - ${isSale ? 'বাকি বিক্রয়' : 'টাকা পরিশোধ'}',
                            style: pw.TextStyle(font: font, fontSize: 8),
                          ),
                          pw.Text(
                            '৳${trans.amount.toStringAsFixed(0)}',
                            style: pw.TextStyle(font: font, fontSize: 8, color: isSale ? PdfColors.red : PdfColors.green),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by Amar Dokan', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('Page ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ],
        ),
      ],
    );
  }
}
