import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';
import 'print_invoice_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SaleDetailScreen extends StatelessWidget {
  final Sale sale;

  const SaleDetailScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: const Text('বিক্রির বিবরণ', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PrintInvoiceScreen(sale: sale)),
            ),
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
            _buildInvoiceHeader(context),
            const SizedBox(height: 16),
            _buildItemsList(context),
            const SizedBox(height: 16),
            _buildSummarySection(context),
            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('ইনভয়েস #${l10n.formatDigits(sale.invoiceId)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text(
                     l10n.formatDigits(DateFormat('dd MMMM, yyyy • hh:mm a').format(sale.saleDate)),
                     style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                   ),
                ],
              ),
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                 decoration: BoxDecoration(
                   color: sale.paymentMethod == 'cash'
                       ? Colors.green.withValues(alpha: 0.15)
                       : Colors.red.withValues(alpha: 0.15),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   sale.paymentMethod == 'cash' ? 'নগদ বিক্রি' : 'বাকি বিক্রি',
                   style: TextStyle(
                     color: sale.paymentMethod == 'cash' ? Colors.green : Colors.red,
                     fontWeight: FontWeight.bold,
                     fontSize: 12,
                   ),
                 ),
               ),
            ],
          ),
          if (sale.customerName != null) ...[
            const Divider(height: 32),
            Row(
              children: [
                 Icon(Icons.person_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('ক্রেতা: ${sale.customerName}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
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
                      Text('${l10n.formatDigits(item.quantity.toString())} x ৳${l10n.formatAmount(item.unitPrice)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                Text('৳${l10n.formatAmount(item.subTotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildSummaryRow('মোট মূল্য', '৳${l10n.formatAmount(sale.totalAmount + sale.discount)}'),
          if (sale.discount > 0) _buildSummaryRow('ডিসকাউন্ট', '- ৳${l10n.formatAmount(sale.discount)}', color: Colors.red),
          const Divider(height: 24),
          _buildSummaryRow('সর্বমোট (Net Total)', '৳${l10n.formatAmount(sale.totalAmount)}', isBold: true, fontSize: 18),
          const SizedBox(height: 8),
          _buildSummaryRow('পরিশোধিত', '৳${l10n.formatAmount(sale.paidAmount)}', color: Colors.green),
          if (sale.dueAmount > 0) _buildSummaryRow('বাকি', '৳${l10n.formatAmount(sale.dueAmount)}', color: Colors.red, isBold: true),
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

  Widget _buildNotesSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('নোট/মন্তব্য', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(sale.notes!, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('বিক্রি ডিলিট নিশ্চিত করুন'),
        content: const Text('এই বিক্রিটি ডিলিট করলে স্টক এবং কাস্টমার ব্যালেন্স আগের অবস্থায় ফিরে যাবে। আপনি কি নিশ্চিত?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('না')),
          TextButton(
            onPressed: () async {
              final repository = SalesRepository(dbHelper: context.read<DatabaseHelper>());
              await repository.deleteSale(sale.id!);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
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
