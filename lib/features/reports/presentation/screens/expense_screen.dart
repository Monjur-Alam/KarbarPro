import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../data/report_repository.dart';
import '../../domain/expense_model.dart';
import '../../../../core/database/database_helper.dart';
import 'package:provider/provider.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('দোকানের খরচ', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: const ExpenseView(),
      ),
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
  List<KhorochCategory> _categories = [];
  double _currentBalance = 0;
  double _totalAdded = 0;
  double _totalExpense = 0;
  bool _isLoading = true;
  bool _isBackgroundLoading = false;
  
  // Filter state
  String _selectedDateFilter = 'এই মাস';
  KhorochCategory? _selectedCategoryFilter;
  String _searchQuery = '';
  DateTimeRange? _customDateRange;
  
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isBackground = false}) async {
    if (isBackground) {
      setState(() => _isBackgroundLoading = true);
    } else {
      setState(() => _isLoading = true);
    }
    try {
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
      final categories = await repo.getKhorochCategories();
      
      final transactions = await repo.getManualKhorochTransactions(
        startDate: startDate,
        endDate: endDate,
        categoryId: _selectedCategoryFilter?.id,
        searchQuery: _searchQuery,
      );
      
      final summary = await repo.getManualKhorochSummary(
        startDate: startDate,
        endDate: endDate,
        categoryId: _selectedCategoryFilter?.id,
      );
      
      setState(() {
        _currentBalance = balance;
        _categories = categories;
        _totalAdded = (summary['totalIncome'] as num).toDouble();
        _totalExpense = (summary['totalExpense'] as num).toDouble();
        _transactions = transactions;
      });
    } catch (e) {
      debugPrint('Error loading Khoroch data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ডেটা লোড করতে সমস্যা হয়েছে: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBackgroundLoading = false;
        });
      }
    }
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

    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Stack(
      children: [
        Column(
          children: [
            Visibility(
              visible: !isKeyboardVisible,
              maintainState: true,
              child: _buildBalanceHeader(),
            ),
            _buildFilterSection(),
            if (_isBackgroundLoading)
              const LinearProgressIndicator(minHeight: 2),
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
        Visibility(
          visible: !isKeyboardVisible,
          child: _buildStickyBottomButtons(context),
        ),
      ],
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
      ),
      child: Row(
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
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              // Date Filter
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          child: Text(value, style: const TextStyle(fontSize: 13)),
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
                          _loadData(isBackground: true);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Category Filter
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<KhorochCategory?>(
                      value: _selectedCategoryFilter,
                      isExpanded: true,
                      hint: const Text('সব খাত', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<KhorochCategory?>(
                          value: null,
                          child: Text('সব খাত', style: TextStyle(fontSize: 13)),
                        ),
                        ..._categories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategoryFilter = value);
                        _loadData(isBackground: true);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Reset Button
              if (_selectedDateFilter != 'এই মাস' || _selectedCategoryFilter != null || _searchQuery.isNotEmpty)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateFilter = 'এই মাস';
                      _selectedCategoryFilter = null;
                      _searchQuery = '';
                      _searchController.clear();
                      _customDateRange = null;
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.blue, size: 24),
                  tooltip: 'ফিল্টার রিসেট',
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'বিবরণ বা খাত দিয়ে খুঁজুন...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        _loadData(isBackground: true);
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                setState(() => _searchQuery = value);
                _loadData(isBackground: true);
              });
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
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
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
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white),
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
    return Dismissible(
      key: Key('trans_${trans.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, trans);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white),
            Text('মুছে ফেলুন', style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), 
          side: BorderSide(color: Colors.grey.shade100)
        ),
        elevation: 0,
        child: ListTile(
          onTap: () => _showEditTransactionDialog(context, trans),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isIncome ? Icons.add : Icons.remove,
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
          trailing: Text(
            '${isIncome ? "+" : "-"} ৳${_toBengaliDigits(trans.amount.toStringAsFixed(0))}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isIncome ? Colors.green : Colors.red
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTransactionDialog(BuildContext context, ShopTransaction trans) {
    final amountController = TextEditingController(text: trans.amount.toString());
    final descriptionController = TextEditingController(text: trans.description ?? '');
    String selectedType = trans.transactionType;
    KhorochCategory? selectedCategory = _categories.firstWhere(
      (c) => c.id == trans.categoryId || c.name == trans.category,
      orElse: () => KhorochCategory(id: trans.categoryId, name: trans.category ?? '', transactionType: trans.transactionType),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('লেনদেন সম্পাদনা'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'ধরন',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('টাকা যোগ (Income)')),
                    DropdownMenuItem(value: 'expense', child: Text('খরচ (Expense)')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                      selectedCategory = null; // Reset category when type changes
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<KhorochCategory?>(
                  value: _categories.any((c) => c.id == selectedCategory?.id) ? selectedCategory : null,
                  decoration: const InputDecoration(
                    labelText: 'খাত বা উৎস',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  hint: const Text('খাত নির্বাচন করুন'),
                  items: [
                    DropdownMenuItem<KhorochCategory?>(
                      value: null,
                      child: Text(
                        '+ নতুন খাত যোগ করুন',
                        style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._categories
                        .where((c) => c.transactionType == selectedType)
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat.name),
                            )),
                  ],
                  onChanged: (value) async {
                    if (value == null) {
                      final newCat = await _showAddCategoryDialog(context, selectedType);
                      if (newCat != null) {
                        await _loadData();
                        setDialogState(() => selectedCategory = newCat);
                      }
                    } else {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
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
                if (selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('খাত নির্বাচন করুন')));
                  return;
                }

                try {
                  final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
                  await repo.updateShopTransaction(
                    transactionId: trans.id!,
                    type: selectedType,
                    amount: amount,
                    category: selectedCategory!.name,
                    categoryId: selectedCategory!.id,
                    description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                    date: trans.transactionDate,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadData(isBackground: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('লেনদেন আপডেট করা হয়েছে')),
                  );
                } catch (e) {
                  print('ERR_LOG: Update failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('আপডেট করতে সমস্যা হয়েছে: $e')),
                    );
                  }
                }
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

  Future<bool?> _showDeleteConfirmation(BuildContext context, ShopTransaction trans) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('নিশ্চিত করুন'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('আপনি কি এই লেনদেনটি মুছে ফেলতে চান?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('পরিমাণ:', style: TextStyle(color: Colors.grey)),
                      Text(
                        '৳${_toBengaliDigits(trans.amount.toStringAsFixed(0))}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('খাত:', style: TextStyle(color: Colors.grey)),
                      Text(
                        trans.category ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('বাতিল')
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
                await repo.deleteShopTransaction(trans.id!);

                if (!context.mounted) return;
                Navigator.pop(context, true);
                _loadData(isBackground: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('লেনদেন মুছে ফেলা হয়েছে')),
                );
              } catch (e) {
                print('ERR_LOG: Delete failed: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('মুছে ফেলতে সমস্যা হয়েছে: $e')),
                  );
                }
                Navigator.pop(context, false);
              }
            },
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
  }

  Future<KhorochCategory?> _showAddCategoryDialog(BuildContext context, String type) async {
    final controller = TextEditingController();
    return showDialog<KhorochCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নতুন খাত যোগ করুন'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'খাতের নাম',
            hintText: 'উদা: যাতায়াত',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
              final categories = await repo.getKhorochCategories();
              
              if (categories.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('এই নামে ইতিমধ্যে একটি খাত আছে')));
                }
                return;
              }

              final category = KhorochCategory(name: name, transactionType: type);
              final id = await repo.addKhorochCategory(category);
              
              if (context.mounted) {
                Navigator.pop(context, KhorochCategory(id: id, name: name, transactionType: type));
              }
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(BuildContext context, String type) {
    final isIncome = type == 'income';
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    KhorochCategory? selectedCategory;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isIncome ? 'টাকা যোগ করুন' : 'খরচ রেকর্ড করুন'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Dropdown with Search-like feel and Add New
                DropdownButtonFormField<KhorochCategory?>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: isIncome ? 'আয়ের উৎস' : 'খরচের খাত',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isExpanded: true,
                  hint: const Text('খাত নির্বাচন করুন'),
                  items: [
                    DropdownMenuItem<KhorochCategory?>(
                      value: null,
                      child: Text(
                        '+ নতুন খাত যোগ করুন',
                        style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._categories
                        .where((c) => c.transactionType == type)
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat.name),
                            )),
                  ],
                  onChanged: (value) async {
                    if (value == null) {
                      // Show add new category dialog
                      final newCat = await _showAddCategoryDialog(context, type);
                      if (newCat != null) {
                        await _loadData(); // Refresh main list
                        setDialogState(() => selectedCategory = newCat);
                      }
                    } else {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
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
                if (selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('খাত নির্বাচন করুন')));
                  return;
                }

                final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
                await repo.addShopTransaction(
                  type: type,
                  amount: amount,
                  category: selectedCategory!.name,
                  categoryId: selectedCategory!.id,
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
      ),
    );
  }
}
