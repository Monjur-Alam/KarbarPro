import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/sale.dart';
import '../../../core/services/invoice_service.dart';
import '../data/sales_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/database/database_helper.dart';

class SaleDetailScreen extends StatelessWidget {
  final Sale sale;

  const SaleDetailScreen({super.key, required this.sale});

  String _toBengaliDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], bengali[i]);
    }
    return input;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##,###');
    return '৳${_toBengaliDigits(formatter.format(amount))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('বিক্রির বিবরণ', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => InvoiceService.shareReceipt(sale),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () => InvoiceService.printReceipt(sale),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInvoiceHeader(),
            const SizedBox(height: 16),
            _buildItemsList(),
            const SizedBox(height: 16),
            _buildSummarySection(),
            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('ইনভয়েস #${_toBengaliDigits(sale.invoiceId)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text(
                     _toBengaliDigits(DateFormat('dd MMMM, yyyy • hh:mm a').format(sale.saleDate)),
                     style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                   ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sale.paymentMethod == 'cash' ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sale.paymentMethod == 'cash' ? 'নগদ বিক্রি' : 'বাকি বিক্রি',
                  style: TextStyle(color: sale.paymentMethod == 'cash' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          if (sale.customerName != null) ...[
            const Divider(height: 32),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text('ক্রেতা: ${sale.customerName}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('পণ্যের বিবরণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ...sale.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${_toBengaliDigits(item.quantity.toString())} x ${_formatCurrency(item.unitPrice)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Text(_formatCurrency(item.subTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildSummaryRow('মোট মূল্য', _formatCurrency(sale.totalAmount + sale.discount)),
          if (sale.discount > 0) _buildSummaryRow('ডিসকাউন্ট', '- ${_formatCurrency(sale.discount)}', color: Colors.red),
          const Divider(height: 24),
          _buildSummaryRow('সর্বমোট (Net Total)', _formatCurrency(sale.totalAmount), isBold: true, fontSize: 18),
          const SizedBox(height: 8),
          _buildSummaryRow('পরিশোধিত', _formatCurrency(sale.paidAmount), color: Colors.green),
          if (sale.dueAmount > 0) _buildSummaryRow('বাকি', _formatCurrency(sale.dueAmount), color: Colors.red, isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('নোট/মন্তব্য', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(sale.notes!, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('বিক্রি ডিলিট নিশ্চিত করুন'),
        content: const Text('এই বিক্রিটি ডিলিট করলে স্টক এবং কাস্টমার ব্যালেন্স আগের অবস্থায় ফিরে যাবে। আপনি কি নিশ্চিত?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('না')),
          TextButton(
            onPressed: () async {
              final repository = SalesRepository(dbHelper: context.read<DatabaseHelper>());
              await repository.deleteSale(sale.id!);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back from detail
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('বিক্রি ডিলিট করা হয়েছে')));
              }
            },
            child: const Text('হ্যাঁ, ডিলিট করুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
