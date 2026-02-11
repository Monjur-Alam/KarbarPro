import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../data/report_repository.dart';
import '../../domain/due_ledger_model.dart';
import '../../../../core/database/database_helper.dart';

class DueLedgerScreen extends StatelessWidget {
  const DueLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('বাকি খাতা', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const DueLedgerView(),
    );
  }
}

class DueLedgerView extends StatefulWidget {
  const DueLedgerView({super.key});

  @override
  State<DueLedgerView> createState() => _DueLedgerViewState();
}

class _DueLedgerViewState extends State<DueLedgerView> {
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
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
        onTap: () => _showCustomerMenu(context, customer),
      ),
    );
  }

  void _showCustomerMenu(BuildContext context, CustomerDue customer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.payments_outlined, color: Colors.green),
            title: const Text('বকেয়া পরিশোধের হিসাব রাখুন'),
            subtitle: const Text('কাস্টমারের কাছ থেকে টাকা জমা নিন'),
            onTap: () {
              Navigator.pop(context);
              _showPaymentCollectionDialog(context, customer);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blue),
            title: const Text('বাকি লেনদেনের ইতিহাস'),
            subtitle: const Text('আগের সব সেল ও পেমেন্ট রেকর্ড'),
            onTap: () {
              Navigator.pop(context);
              _showTransactionHistorySheet(context, customer);
            },
          ),
          ListTile(
            leading: const Icon(Icons.call_outlined, color: Colors.orange),
            title: const Text('যোগাযোগ করুন'),
            onTap: () {
              Navigator.pop(context);
              _showContactOptions(context, customer);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showPaymentCollectionDialog(BuildContext context, CustomerDue customer) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('টাকা জমা নিন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('কাস্টমার: ${customer.name}'),
            const SizedBox(height: 8),
            Text('বর্তমান বাকি: ৳${_toBengaliDigits(customer.currentCreditBalance.toStringAsFixed(0))}', 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'জমা করা টাকার পরিমাণ',
                prefixText: '৳',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'নোট (ঐচ্ছিক)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক পরিমাণ লিখুন')));
                return;
              }
              if (amount > customer.currentCreditBalance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('জমা দেওয়ার পরিমাণ বাকির চেয়ে বেশি হতে পারবে না')));
                return;
              }

              final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
              await repo.recordCustomerPayment(
                customerId: customer.id,
                amount: amount,
                notes: notesController.text,
              );

              if (!mounted) return;
              Navigator.pop(context);
              _loadDueLedger();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('টাকা জমা নেওয়া সফল হয়েছে')));
            },
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );
  }

  void _showTransactionHistorySheet(BuildContext context, CustomerDue customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => FutureBuilder<List<CustomerTransaction>>(
          future: ReportRepository(dbHelper: context.read<DatabaseHelper>()).getCustomerTransactionHistory(customer.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final history = snapshot.data!;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('লেনদেনের ইতিহাস - ${customer.name}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Divider(),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('কোনো লেনদেনের ইতিহাস নেই'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: history.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final trans = history[index];
                            final isSale = trans.transactionType == 'sale';
                            return ListTile(
                              title: Text(isSale ? 'পণ্য ক্রয় (বাকি)' : 'টাকা পরিশোধ'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (trans.description != null) Text(trans.description!, style: const TextStyle(fontSize: 12)),
                                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(trans.transactionDate), 
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isSale ? "+" : "-"} ৳${_toBengaliDigits(trans.amount.toStringAsFixed(0))}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSale ? Colors.red : Colors.green,
                                    ),
                                  ),
                                  Text('ব্যালেন্স: ৳${_toBengaliDigits(trans.balanceAfter.toStringAsFixed(0))}', 
                                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
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
