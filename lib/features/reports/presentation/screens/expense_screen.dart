import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/report_repository.dart';
import '../../domain/expense_model.dart';
import '../../../../core/database/database_helper.dart';
import 'package:provider/provider.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final List<Expense> _expenses = [];
  bool _isLoading = true;
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
    final start = DateTime.now().subtract(const Duration(days: 30));
    final end = DateTime.now();
    final expenses = await repo.getExpenses(start, end);
    setState(() {
      _expenses.clear();
      _expenses.addAll(expenses);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('দোকানের খরচ', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExpenses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final expense = _expenses[index];
                    return _buildExpenseCard(expense);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('কোন খরচ রেকর্ড করা হয়নি', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade50,
          child: const Icon(Icons.money_off, color: Colors.red, size: 20),
        ),
        title: Text(expense.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${_toBengaliDigits(DateFormat('dd MMM, yyyy').format(expense.expenseDate))}${expense.description != null ? ' • ${expense.description}' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Text(
          '৳${_toBengaliDigits(expense.amount.toStringAsFixed(0))}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
        ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নতুন খরচ যোগ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'খরচের খাত (উদা: বিদ্যুৎ বিল)'),
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
              if (_categoryController.text.isNotEmpty && _amountController.text.isNotEmpty) {
                final expense = Expense(
                  category: _categoryController.text,
                  amount: double.parse(_amountController.text),
                  description: _descriptionController.text,
                  expenseDate: DateTime.now(),
                );
                final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
                await repo.addExpense(expense);
                if (!context.mounted) return;
                _categoryController.clear();
                _amountController.clear();
                _descriptionController.clear();
                Navigator.pop(context);
                _loadExpenses();
              }
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }
}
