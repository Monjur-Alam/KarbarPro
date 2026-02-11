import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/report_repository.dart';
import '../../domain/expense_model.dart';
import '../../../../core/database/database_helper.dart';
import 'package:provider/provider.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('দোকানের খরচ', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const ExpenseView(),
    );
  }
}

class ExpenseView extends StatefulWidget {
  const ExpenseView({super.key});

  @override
  State<ExpenseView> createState() => _ExpenseViewState();
}

class _ExpenseViewState extends State<ExpenseView> {
  List<ShopTransaction> _transactions = [];
  double _currentBalance = 0;
  bool _isLoading = true;
  
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
    
    final balance = await repo.getShopMainBalance();
    final start = DateTime.now().subtract(const Duration(days: 30));
    final end = DateTime.now();
    final transactions = await repo.getShopTransactions(start, end);
    
    setState(() {
      _currentBalance = balance;
      _transactions = transactions;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildBalanceHeader(),
        _buildActionButtons(context),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('লেনদেনের ইতিহাস', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        Expanded(
          child: _transactions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final trans = _transactions[index];
                    return _buildTransactionCard(trans);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
      ),
      child: Column(
        children: [
          const Text('দোকানের মেইন ব্যালেন্স', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '৳${_toBengaliDigits(_currentBalance.toStringAsFixed(0))}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showTransactionDialog(context, 'income'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('টাকা যোগ করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showTransactionDialog(context, 'expense'),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('খরচ করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
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
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('কোনো লেনদেন রেকর্ড করা হয়নি', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(ShopTransaction trans) {
    final isIncome = trans.transactionType == 'income';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
          child: Icon(
            isIncome ? Icons.add : Icons.remove, 
            color: isIncome ? Colors.green : Colors.red, 
            size: 20
          ),
        ),
        title: Text(trans.category ?? (isIncome ? 'টাকা যোগ' : 'খরচ'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trans.description != null && trans.description!.isNotEmpty) 
              Text(trans.description!, style: const TextStyle(fontSize: 12)),
            Text(
              _toBengaliDigits(DateFormat('dd MMM, yyyy').format(trans.transactionDate)),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? "+" : "-"} ৳${_toBengaliDigits(trans.amount.toStringAsFixed(0))}',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16, 
                color: isIncome ? Colors.green : Colors.red
              ),
            ),
            Text('ব্যালেন্স: ৳${_toBengaliDigits(trans.balanceAfter.toStringAsFixed(0))}', 
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showTransactionDialog(BuildContext context, String type) {
    final isIncome = type == 'income';
    _amountController.clear();
    _descriptionController.clear();
    _categoryController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isIncome ? 'টাকা যোগ করুন' : 'নতুন খরচ যোগ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: isIncome ? 'আয়ের উৎস (ঐচ্ছিক)' : 'খরচের খাত (উদা: বিদ্যুৎ বিল)'
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'টাকার পরিমাণ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'বিবরণ (ঐচ্ছিক)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক পরিমাণ লিখুন')));
                return;
              }

              final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
              await repo.addShopTransaction(
                type: type,
                amount: amount,
                category: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
              );

              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isIncome ? 'টাকা সফলভাবে যোগ করা হয়েছে' : 'খরচ সফলভাবে রেকর্ড করা হয়েছে'))
              );
            },
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );
  }
}
