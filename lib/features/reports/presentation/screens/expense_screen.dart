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
  double _totalAdded = 0;
  double _totalExpense = 0;
  bool _isLoading = true;
  
  // Filter state
  String _selectedDateFilter = 'এই মাস';
  String _searchQuery = '';
  DateTimeRange? _customDateRange;
  
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
    
    // Calculate date range based on filter
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (_selectedDateFilter) {
      case 'আজ':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'গতকাল':
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 'গত ৭ দিন':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case 'গত ৩০ দিন':
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        break;
      case 'এই মাস':
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case 'গত মাস':
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'কাস্টম রেঞ্জ':
        if (_customDateRange != null) {
          startDate = _customDateRange!.start;
          endDate = _customDateRange!.end;
        }
        break;
    }

    final balance = await repo.getShopMainBalance();
    final transactions = await repo.getManualKhorochTransactions(
      startDate: startDate,
      endDate: endDate,
      searchQuery: _searchQuery,
    );
    
    final summary = await repo.getManualKhorochSummary(
      startDate: startDate,
      endDate: endDate,
    );
    
    setState(() {
      _currentBalance = balance;
      _totalAdded = (summary['totalIncome'] as num).toDouble();
      _totalExpense = (summary['totalExpense'] as num).toDouble();
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

    return Stack(
      children: [
        Column(
          children: [
            _buildBalanceHeader(),
            _buildFilterSection(),
            Expanded(
              child: _transactions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Extra padding for sticky buttons
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final trans = _transactions[index];
                        return _buildTransactionCard(trans);
                      },
                    ),
            ),
          ],
        ),
        _buildStickyBottomButtons(context),
      ],
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'মূল ব্যালেন্স: ৳${_toBengaliDigits(_currentBalance.toStringAsFixed(0))}',
            style: const TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.bold, 
              color: Colors.black87
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('মোট যোগ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '৳${_toBengaliDigits(_totalAdded.toStringAsFixed(0))}',
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.green
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              Expanded(
                child: Column(
                  children: [
                    const Text('মোট খরচ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '৳${_toBengaliDigits(_totalExpense.toStringAsFixed(0))}',
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.red
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDateFilter,
                      isExpanded: true,
                      items: [
                        'আজ', 'গতকাল', 'গত ৭ দিন', 'গত ৩০ দিন', 'এই মাস', 'গত মাস', 'কাস্টম রেঞ্জ'
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value == 'কাস্টম রেঞ্জ') {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDateFilter = value!;
                              _customDateRange = picked;
                            });
                            _loadData();
                          }
                        } else {
                          setState(() => _selectedDateFilter = value!);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_selectedDateFilter != 'এই মাস' || _searchQuery.isNotEmpty)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateFilter = 'এই মাস';
                      _searchQuery = '';
                      _searchController.clear();
                      _customDateRange = null;
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.filter_alt_off, color: Colors.red),
                  tooltip: 'ফিল্টার মুছুন',
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'বিবরণ বা খাত দিয়ে খুঁজুন...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomButtons(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showTransactionDialog(context, 'income'),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('টাকা যোগ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showTransactionDialog(context, 'expense'),
                icon: const Icon(Icons.remove, color: Colors.white),
                label: const Text('খরচ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty || _selectedDateFilter != 'এই মাস'
                ? Icons.search_off
                : Icons.history, 
            size: 64, 
            color: Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedDateFilter != 'এই মাস'
                ? 'কোনো ফলাফল পাওয়া যায়নি' 
                : 'কোনো লেনদেন রেকর্ড করা হয়নি', 
            style: const TextStyle(color: Colors.grey)
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(ShopTransaction trans) {
    final isIncome = trans.transactionType == 'income';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey.shade100)
      ),
      elevation: 0,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline, 
            color: isIncome ? Colors.green : Colors.red, 
            size: 24
          ),
        ),
        title: Text(
          trans.category ?? (isIncome ? 'টাকা যোগ' : 'খরচ'), 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trans.description != null && trans.description!.isNotEmpty) 
              Text(
                trans.description!, 
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              _toBengaliDigits(DateFormat('dd MMM, yyyy').format(trans.transactionDate)),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
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
                Text(
                  'ব্যালেন্স: ৳${_toBengaliDigits(trans.balanceAfter.toStringAsFixed(0))}', 
                  style: const TextStyle(fontSize: 10, color: Colors.grey)
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditTransactionDialog(context, trans);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(context, trans);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit', 
                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('সম্পাদনা')])
                ),
                const PopupMenuItem(
                  value: 'delete', 
                  child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('মুছে ফেলুন', style: TextStyle(color: Colors.red))])
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionDialog(BuildContext context, ShopTransaction trans) {
    final amountController = TextEditingController(text: trans.amount.toString());
    final descriptionController = TextEditingController(text: trans.description ?? '');
    final categoryController = TextEditingController(text: trans.category ?? '');
    String selectedType = trans.transactionType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('লেনদেন সম্পাদনা'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'ধরন',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('টাকা যোগ (Income)')),
                    DropdownMenuItem(value: 'expense', child: Text('খরচ (Expense)')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: selectedType == 'income' ? 'আয়ের উৎস' : 'খরচের খাত',
                    hintText: selectedType == 'income' ? 'উদা: ইনভেস্টমেন্ট' : 'উদা: দোকান ভাড়া',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'টাকার পরিমাণ',
                    prefixText: '৳',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'বিবরণ (ঐচ্ছিক)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('বাতিল')
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক পরিমাণ লিখুন')));
                  return;
                }

                final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
                await repo.updateShopTransaction(
                  transactionId: trans.id!,
                  type: selectedType,
                  amount: amount,
                  category: categoryController.text.isNotEmpty ? categoryController.text : null,
                  description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                  date: trans.transactionDate,
                );

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লেনদেন আপডেট করা হয়েছে')));
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('সংরক্ষণ করুন'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ShopTransaction trans) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('মুছে ফেলতে চান?'),
        content: const Text('এই লেনদেনটি মুছে ফেললে মেইন ব্যালেন্স পুনরায় গণনা করা হবে। আপনি কি নিশ্চিত?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
              await repo.deleteShopTransaction(trans.id!);

              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লেনদেন মুছে ফেলা হয়েছে')));
            },
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(BuildContext context, String type) {
    final isIncome = type == 'income';
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isIncome ? 'টাকা যোগ করুন' : 'খরচ রেকর্ড করুন'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: isIncome ? 'আয়ের উৎস' : 'খরচের খাত',
                  hintText: isIncome ? 'উদা: জমানো টাকা' : 'উদা: বিদ্যুৎ বিল',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'টাকার পরিমাণ',
                  prefixText: '৳',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'বিবরণ (ঐচ্ছিক)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
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

              final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
              await repo.addShopTransaction(
                type: type,
                amount: amount,
                category: categoryController.text.isNotEmpty ? categoryController.text : null,
                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                source: 'manual_khoroch',
              );

              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isIncome ? 'সাফল্যের সাথে যোগ করা হয়েছে' : 'খরচ রেকর্ড করা হয়েছে'))
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isIncome ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );
  }
}
