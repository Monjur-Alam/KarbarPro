import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/report_repository.dart';
import '../../domain/due_ledger_model.dart';
import '../../../../core/database/database_helper.dart';

class DueLedgerScreen extends StatefulWidget {
  const DueLedgerScreen({super.key});

  @override
  State<DueLedgerScreen> createState() => _DueLedgerScreenState();
}

class _DueLedgerScreenState extends State<DueLedgerScreen> {
  List<CustomerDue> _dueCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDueLedger();
  }

  Future<void> _loadDueLedger() async {
    setState(() => _isLoading = true);
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
    final customers = await repo.getDueCustomers();
    setState(() {
      _dueCustomers = customers;
      _isLoading = false;
    });
  }

  String _toBengaliDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], bengali[i]);
    }
    return input;
  }

  @override
  Widget build(BuildContext context) {
    double totalDue = _dueCustomers.fold(0, (sum, c) => sum + c.currentCreditBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('বাকি খাতা', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTotalDueHeader(totalDue),
                Expanded(
                  child: _dueCustomers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _dueCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _dueCustomers[index];
                            return _buildCustomerDueCard(customer);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTotalDueHeader(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(bottom: BorderSide(color: Colors.red.shade100)),
      ),
      child: Column(
        children: [
          const Text('সর্বমোট পাওনা (বাকি)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '৳${_toBengaliDigits(total.toStringAsFixed(0))}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade200),
          const SizedBox(height: 16),
          const Text('কারো কাছে কোনো টাকা পাওনা নেই', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCustomerDueCard(CustomerDue customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Text(customer.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(customer.phone ?? 'ফোন নম্বর নেই', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '৳${_toBengaliDigits(customer.currentCreditBalance.toStringAsFixed(0))}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
            ),
            const Text('বাকি', style: TextStyle(fontSize: 10, color: Colors.red)),
          ],
        ),
        onTap: () {
          if (customer.phone != null) {
            _showContactOptions(context, customer);
          }
        },
      ),
    );
  }

  void _showContactOptions(BuildContext context, CustomerDue customer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.call, color: Colors.green),
            title: const Text('কল করুন'),
            onTap: () async {
              final url = 'tel:${customer.phone}';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.message, color: Colors.blue),
            title: const Text('এসএমএস পাঠান'),
            onTap: () async {
              final url = 'sms:${customer.phone}?body=আপনার দোকানের বাকি ৳${customer.currentCreditBalance} পরিশোধ করার জন্য অনুরোধ করা হলো।';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
