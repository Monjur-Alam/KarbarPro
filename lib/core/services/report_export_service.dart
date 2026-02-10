import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../features/reports/domain/report_models.dart';
import '../../features/sales/domain/sale.dart';

class ReportExportService {
  static Future<void> exportProductReport(List<ProductReportItem> products, DateTime start, DateTime end) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/HindSiliguri-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) => [
          _buildPdfHeader(start, end),
          pw.SizedBox(height: 20),
          _buildPdfSectionTitle('বিস্তারিত পণ্য রিপোর্ট'),
          _buildPdfProductsTable(products),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Product_Report');
  }

  static Future<void> exportStockReport(List<Map<String, dynamic>> products) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/HindSiliguri-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) => [
          pw.Text('আমার দোকান - স্টক রিপোর্ট', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text('তারিখ: ${DateFormat('dd MMM, yyyy').format(DateTime.now())}'),
          pw.Divider(),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['নাম', 'স্টক', 'ক্রয় মূল্য'],
            data: products.map((p) => [
              p['name'],
              p['current_stock'].toString(),
              '৳${(p['purchase_price'] as num).toStringAsFixed(2)}',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Stock_Report');
  }

  static Future<void> exportToPdf(SalesReportData data, List<Sale> sales, DateTime start, DateTime end) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/HindSiliguri-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) => [
          _buildPdfHeader(start, end),
          pw.SizedBox(height: 20),
          _buildPdfSummary(data.stats),
          pw.SizedBox(height: 24),
          _buildPdfSectionTitle('বেশি বিক্রিত পণ্য'),
          _buildPdfProductsTable(data.topProducts),
          pw.SizedBox(height: 24),
          _buildPdfSectionTitle('বিক্রির তালিকা'),
          _buildPdfSalesTable(sales),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Sales_Report_${DateFormat('dd_MM_yyyy').format(start)}_to_${DateFormat('dd_MM_yyyy').format(end)}',
    );
  }

  static pw.Widget _buildPdfHeader(DateTime start, DateTime end) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('আমার দোকান - বিক্রির রিপোর্ট', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('সময়সীমা: ${DateFormat('dd MMM, yyyy').format(start)} হতে ${DateFormat('dd MMM, yyyy').format(end)} পর্যন্ত'),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildPdfSummary(SummaryStats stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('সারসংক্ষেপ', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryItem('মোট বিক্রি', stats.salesCount.toString()),
            _buildSummaryItem('মোট আয়', '৳${stats.totalRevenue.toStringAsFixed(2)}'),
            _buildSummaryItem('মোট লাভ', '৳${stats.totalProfit.toStringAsFixed(2)}'),
            _buildSummaryItem('গড় বিক্রয়', '৳${stats.averageSale.toStringAsFixed(2)}'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _buildPdfProductsTable(List<ProductReportItem> products) {
    return pw.TableHelper.fromTextArray(
      headers: ['পণ্য', 'পরিমাণ', 'আয়', 'লাভ'],
      data: products.map((p) => [
        p.productName,
        p.quantitySold.toString(),
        p.totalRevenue.toStringAsFixed(2),
        p.totalProfit.toStringAsFixed(2),
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _buildPdfSalesTable(List<Sale> sales) {
    return pw.TableHelper.fromTextArray(
      headers: ['তারিখ', 'ইনভয়েস', 'ক্রেতা', 'ধরণ', 'মোট টাকা'],
      data: sales.map((s) => [
        DateFormat('dd/MM/yy').format(s.saleDate),
        s.invoiceId,
        s.customerName ?? '-',
        s.paymentMethod == 'cash' ? 'নগদ' : 'বাকি',
        s.totalAmount.toStringAsFixed(2),
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static Future<void> exportToExcel(SalesReportData data, List<Sale> sales, DateTime start, DateTime end) async {
    final excel = Excel.createExcel();
    
    // Summary Sheet
    final Sheet summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue('বিক্রির রিপোর্ট সারসংক্ষেপ')]);
    summarySheet.appendRow([TextCellValue('সময়সীমা'), TextCellValue('${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}')]);
    summarySheet.appendRow([]);
    summarySheet.appendRow([TextCellValue('ম্যাট্রিক'), TextCellValue('মান')]);
    summarySheet.appendRow([TextCellValue('মোট বিক্রি'), IntCellValue(data.stats.salesCount)]);
    summarySheet.appendRow([TextCellValue('মোট আয়'), DoubleCellValue(data.stats.totalRevenue)]);
    summarySheet.appendRow([TextCellValue('মোট লাভ'), DoubleCellValue(data.stats.totalProfit)]);
    summarySheet.appendRow([TextCellValue('গড় বিক্রয়'), DoubleCellValue(data.stats.averageSale)]);

    // Sales List Sheet
    final Sheet salesSheet = excel['Sales List'];
    salesSheet.appendRow([
      TextCellValue('তারিখ'), 
      TextCellValue('ইনভয়েস'), 
      TextCellValue('ক্রেতা'), 
      TextCellValue('ধরণ'), 
      TextCellValue('মোট টাকা')
    ]);
    for (var s in sales) {
      salesSheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(s.saleDate)),
        TextCellValue(s.invoiceId),
        TextCellValue(s.customerName ?? '-'),
        TextCellValue(s.paymentMethod),
        DoubleCellValue(s.totalAmount)
      ]);
    }

    // Save and Share
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Sales_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles([XFile(file.path)], subject: 'Sales Report Excel');
    }
  }
}
