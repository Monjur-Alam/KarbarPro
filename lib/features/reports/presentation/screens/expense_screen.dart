import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../data/report_repository.dart';
import '../../domain/expense_model.dart';
import '../../../../core/database/database_helper.dart';
import 'package:provider/provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_item.dart';
import '../widgets/filter_tab.dart';
import '../widgets/month_selector.dart';
import '../../utils/date_formatter_utils.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: const ExpenseView(),
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
  String _selectedPeriod = 'মাসিক'; // দৈনিক, মাসিক, বাৎসরিক, পরিসর
  String _selectedFilter = 'সব'; // সব, জমা, খরচ
  
  // Specific selections
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = DateFormat('MMM yyyy').format(DateTime.now());
  String _selectedYear = DateFormat('yyyy').format(DateTime.now());
  
  KhorochCategory? _selectedCategoryFilter;
  String _searchQuery = '';
  DateTimeRange? _customDateRange;
  
  final _searchController = TextEditingController();
  Timer? _debounce;

  final List<DateTime> _days = [];
  final List<String> _months = [];
  final List<String> _years = [];

  @override
  void initState() {
    super.initState();
    _generateLists();
    _loadData();
  }

  void _generateLists() {
    final now = DateTime.now();
    
    // Generate last 30 days
    _days.clear();
    for (int i = 0; i < 30; i++) {
      _days.add(now.subtract(Duration(days: i)));
    }

    // Generate last 12 months
    _months.clear();
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      _months.add(DateFormat('MMM yyyy').format(date));
    }

    // Generate last 10 years
    _years.clear();
    for (int i = 0; i < 10; i++) {
      _years.add((now.year - i).toString());
    }
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

      switch (_selectedPeriod) {
        case 'দৈনিক':
          startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
          break;
        case 'মাসিক':
          final parsedMonth = DateFormat('MMM yyyy').parse(_selectedMonth);
          startDate = DateTime(parsedMonth.year, parsedMonth.month, 1);
          endDate = DateTime(parsedMonth.year, parsedMonth.month + 1, 0, 23, 59, 59);
          break;
        case 'বাৎসরিক':
          final yearNum = int.parse(_selectedYear);
          startDate = DateTime(yearNum, 1, 1);
          endDate = DateTime(yearNum, 12, 31, 23, 59, 59);
          break;
        case 'পরিসর':
          if (_customDateRange != null) {
            startDate = _customDateRange!.start;
            endDate = _customDateRange!.end;
          }
          break;
      }

      final balance = await repo.getShopMainBalance();
      final categories = await repo.getKhorochCategories();
      
      // Determine transaction type filter from _selectedFilter
      String? typeFilter;
      if (_selectedFilter == 'জমা') typeFilter = 'income';
      if (_selectedFilter == 'খরচ') typeFilter = 'expense';
      
      final transactions = await repo.getManualKhorochTransactions(
        startDate: startDate,
        endDate: endDate,
        categoryId: _selectedCategoryFilter?.id,
        searchQuery: _searchQuery,
        transactionType: typeFilter,
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


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildPeriodTabs(),
          _buildCurrentSelectionSelector(),
          _buildSelectedDateLabel(),
          _buildSummaryCards(),
          _buildFilterTabs(),
          if (_isBackgroundLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadData(),
              child: _transactions.isEmpty
                   ? _buildEmptyState()
                   : _buildTransactionsList(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFABs(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'দোকানের খরচ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 12,
                color: Color(0xFF757575),
              ),
              const SizedBox(width: 4),
              Text(
                DateFormatterUtils.formatBengaliDate(DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Color(0xFF757575)),
          onPressed: () {
            // Show search/filter options or toggle search bar
          },
        ),
      ],
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPeriodTab('দৈনিক'),
          _buildPeriodTab('মাসিক'),
          _buildPeriodTab('বাৎসরিক'),
          _buildPeriodTab('পরিসর'),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label) {
    final isSelected = _selectedPeriod == label;
    return GestureDetector(
      onTap: () async {
        if (label == 'পরিসর') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() {
              _selectedPeriod = label;
              _customDateRange = picked;
            });
            _loadData();
          }
        } else {
          setState(() => _selectedPeriod = label);
          _loadData(isBackground: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(
                    color: Color(0xFF2196F3),
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF757575),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSelectionSelector() {
    if (_selectedPeriod == 'পরিসর') return const SizedBox.shrink();

    List<dynamic> items = [];
    String? selectedValue;
    Function(dynamic) onSelect;
    String Function(dynamic) labelMapper;

    if (_selectedPeriod == 'দৈনিক') {
      items = _days;
      selectedValue = DateFormat('dd MMM yyyy').format(_selectedDate);
      labelMapper = (item) => DateFormat('dd MMM').format(item as DateTime);
      onSelect = (item) {
        setState(() => _selectedDate = item as DateTime);
        _loadData(isBackground: true);
      };
    } else if (_selectedPeriod == 'মাসিক') {
      items = _months;
      selectedValue = _selectedMonth;
      labelMapper = (item) => (item as String).split(' ').first; // e.g. "Feb"
      onSelect = (item) {
        setState(() => _selectedMonth = item as String);
        _loadData(isBackground: true);
      };
    } else {
      // বাৎসরিক
      items = _years;
      selectedValue = _selectedYear;
      labelMapper = (item) => (item as String);
      onSelect = (item) {
        setState(() => _selectedYear = item as String);
        _loadData(isBackground: true);
      };
    }

    return Container(
      color: Colors.white,
      height: 50,
      child: Row(
        children: [
          if (_selectedPeriod == 'দৈনিক')
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Color(0xFF2196F3)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadData();
                }
              },
            ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true, // Start from right
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final itemLabel = labelMapper(item);
                final bool isSelected;
                
                if (_selectedPeriod == 'দৈনিক') {
                  isSelected = DateFormat('dd MMM yyyy').format(item as DateTime) == selectedValue;
                } else {
                  isSelected = item as String == selectedValue;
                }

                return MonthSelector(
                  month: itemLabel,
                  isSelected: isSelected,
                  onTap: () => onSelect(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateLabel() {
    String labelText = '';
    if (_selectedPeriod == 'দৈনিক') {
      labelText = DateFormat('dd MMM yyyy').format(_selectedDate);
    } else if (_selectedPeriod == 'মাসিক') {
      labelText = _selectedMonth;
    } else if (_selectedPeriod == 'বাৎসরিক') {
      labelText = _selectedYear;
    } else if (_selectedPeriod == 'পরিসর' && _customDateRange != null) {
      labelText = '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange!.end)}';
    }

    if (labelText.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        labelText,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2196F3),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              label: 'জমা',
              amount: '৳${DateFormatterUtils.toBengaliNumber(_totalAdded)}',
              amountColor: const Color(0xFF212121),
              icon: Icons.arrow_downward,
              iconColor: const Color(0xFF4CAF50),
              iconBackgroundColor: const Color(0xFFE8F5E9),
              onTap: () => _showTransactionDialog(context, 'income'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: 'ব্যালেন্স',
              amount: '${_totalAdded - _totalExpense >= 0 ? '+' : '-'}৳${DateFormatterUtils.toBengaliNumber((_totalAdded - _totalExpense).abs())}',
              amountColor: const Color(0xFF4CAF50),
              icon: Icons.folder_outlined,
              iconColor: const Color(0xFF2196F3),
              iconBackgroundColor: const Color(0xFFE3F2FD),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: 'খরচ',
              amount: '৳${DateFormatterUtils.toBengaliNumber(_totalExpense)}',
              amountColor: const Color(0xFF212121),
              icon: Icons.arrow_upward,
              iconColor: const Color(0xFFF44336),
              iconBackgroundColor: const Color(0xFFFFEBEE),
              onTap: () => _showTransactionDialog(context, 'expense'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FilterTab(
            label: 'সব',
            isSelected: _selectedFilter == 'সব',
            onTap: () {
              setState(() => _selectedFilter = 'সব');
              _loadData(isBackground: true);
            },
          ),
          FilterTab(
            label: 'জমা',
            isSelected: _selectedFilter == 'জমা',
            onTap: () {
              setState(() => _selectedFilter = 'জমা');
              _loadData(isBackground: true);
            },
          ),
          FilterTab(
            label: 'খরচ',
            isSelected: _selectedFilter == 'খরচ',
            onTap: () {
              setState(() => _selectedFilter = 'খরচ');
              _loadData(isBackground: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    // Group transactions by date
    final grouped = <String, List<ShopTransaction>>{};
    for (final trans in _transactions) {
      final dateKey = DateFormat('dd MMM yyyy').format(trans.transactionDate);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(trans);
    }

    final dateKeys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: dateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = dateKeys[index];
        final dayTransactions = grouped[dateKey]!;
        
        double dayTotal = 0;
        for (var t in dayTransactions) {
          if (t.transactionType == 'income') dayTotal += t.amount;
          else dayTotal -= t.amount;
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateKey,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'মোট ${dayTotal >= 0 ? '+' : '-'}৳${DateFormatterUtils.toBengaliNumber(dayTotal.abs())}',
                    style: TextStyle(
                      fontSize: 14,
                      color: dayTotal >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: Column(
                children: dayTransactions.map((transaction) {
                  return TransactionItem(
                    transaction: transaction,
                    onTap: () => _showEditTransactionDialog(context, transaction),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          ],
        );
      },
    );
  }

  Widget _buildFABs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'expense',
          backgroundColor: const Color(0xFFF44336),
          onPressed: () => _showTransactionDialog(context, 'expense'),
          child: const Icon(Icons.remove, color: Colors.white),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'income',
          backgroundColor: const Color(0xFF4CAF50),
          onPressed: () => _showTransactionDialog(context, 'income'),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty || _selectedPeriod != 'মাসিক'
                ? Icons.search_off
                : Icons.history, 
            size: 64, 
            color: Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedPeriod != 'মাসিক'
                ? 'কোনো ফলাফল পাওয়া যায়নি' 
                : 'কোনো লেনদেন রেকর্ড করা হয়নি', 
            style: const TextStyle(color: Colors.grey)
          ),
        ],
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
                    DropdownMenuItem(value: 'income', child: Text('টাকা জমা (Joma)')),
                    DropdownMenuItem(value: 'expense', child: Text('খরচ (Khoroch)')),
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
                        '৳${DateFormatterUtils.toBengaliNumber(trans.amount)}',
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
          title: Text(isIncome ? 'টাকা জমা দিন' : 'খরচ রেকর্ড করুন'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Dropdown with Search-like feel and Add New
                DropdownButtonFormField<KhorochCategory?>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: isIncome ? 'জমার উৎস' : 'খরচের খাত',
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
