import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/l10n/app_localizations.dart';
import 'package:printing/printing.dart';
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
    return const SizedBox.shrink(); // This shouldn't be called directly anymore
  }
}

class ExpenseView extends StatefulWidget {
  final String selectedPeriod;
  final DateTime selectedDate;
  final String selectedMonth;
  final String selectedYear;
  final DateTimeRange? customDateRange;
  final Function({
    String? selectedPeriod,
    DateTime? selectedDate,
    String? selectedMonth,
    String? selectedYear,
    DateTimeRange? customDateRange,
  }) onFilterChanged;

  const ExpenseView({
    super.key,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.selectedMonth,
    required this.selectedYear,
    this.customDateRange,
    required this.onFilterChanged,
  });

  @override
  State<ExpenseView> createState() => _ExpenseViewState();
}

class _ExpenseViewState extends State<ExpenseView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ShopTransaction> _transactions = [];
  List<KhorochCategory> _categories = [];
  double _currentBalance = 0;
  double _totalAdded = 0;
  double _totalExpense = 0;
  bool _isLoading = true;
  bool _isBackgroundLoading = false;

  // Filter state (now mostly controlled by widget props and TabController)
  int _selectedTabIndex = 0;

  KhorochCategory? _selectedCategoryFilter;
  String _searchQuery = '';

  final _searchController = TextEditingController();
  Timer? _debounce;

  final List<DateTime> _days = [];
  final List<String> _months = [];
  final List<String> _years = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _selectedTabIndex = _tabController.index);
    });
    _generateLists();
    _loadData();
  }

  @override
  void didUpdateWidget(ExpenseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear ||
        oldWidget.customDateRange != widget.customDateRange) {
      _loadData(isBackground: true);
    }
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
    _tabController.dispose();
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

      switch (widget.selectedPeriod) {
        case 'দৈনিক':
          startDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
          endDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
          break;
        case 'মাসিক':
          final parsedMonth = DateFormat('MMM yyyy').parse(widget.selectedMonth);
          startDate = DateTime(parsedMonth.year, parsedMonth.month, 1);
          endDate = DateTime(parsedMonth.year, parsedMonth.month + 1, 0, 23, 59, 59);
          break;
        case 'বাৎসরিক':
          final yearNum = int.parse(widget.selectedYear);
          startDate = DateTime(yearNum, 1, 1);
          endDate = DateTime(yearNum, 12, 31, 23, 59, 59);
          break;
        case 'পরিসর':
          if (widget.customDateRange != null) {
            startDate = widget.customDateRange!.start;
            endDate = widget.customDateRange!.end;
          }
          break;
      }

      final balance = await repo.getShopMainBalance();
      final categories = await repo.getKhorochCategories();
      
      // We load ALL transactions and filter them locally in the TabBarView
      final transactions = await repo.getManualKhorochTransactions(
        startDate: startDate,
        endDate: endDate,
        categoryId: _selectedCategoryFilter?.id,
        searchQuery: _searchQuery,
        transactionType: null, // Load all
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Column(
        children: [
          _buildPeriodTabs(),
          _buildCurrentSelectionSelector(),
          if (_isBackgroundLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: _buildSummaryCards(),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      minHeight: 48,
                      maxHeight: 48,
                      child: _buildFilterTabs(),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabTransactionsList(null),     // সব
                  _buildTabTransactionsList('income'),  // জমা
                  _buildTabTransactionsList('expense'), // খরচ
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFABs(),
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPeriodTab(context, 'দৈনিক'),
          _buildPeriodTab(context, 'মাসিক'),
          _buildPeriodTab(context, 'বাৎসরিক'),
          _buildPeriodTab(context, 'পরিসর'),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(BuildContext context, String periodValue) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = widget.selectedPeriod == periodValue;
    return GestureDetector(
      onTap: () async {
        if (periodValue == 'পরিসর') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            widget.onFilterChanged(
              selectedPeriod: periodValue,
              customDateRange: picked,
            );
          }
        } else {
          widget.onFilterChanged(selectedPeriod: periodValue);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(
                  bottom: BorderSide(
                    color: colorScheme.primary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Text(
          l10n.getPeriodLabel(periodValue),
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSelectionSelector() {
    if (widget.selectedPeriod == 'পরিসর') return const SizedBox.shrink();

    List<dynamic> items = [];
    String? selectedValue;
    Function(dynamic) onSelect;
    String Function(dynamic) labelMapper;

    if (widget.selectedPeriod == 'দৈনিক') {
      items = _days;
      selectedValue = DateFormat('dd MMM yyyy').format(widget.selectedDate);
      labelMapper = (item) => DateFormat('dd MMM').format(item as DateTime);
      onSelect = (item) {
        widget.onFilterChanged(selectedDate: item as DateTime);
      };
    } else if (widget.selectedPeriod == 'মাসিক') {
      items = _months;
      selectedValue = widget.selectedMonth;
      labelMapper = (item) => (item as String).split(' ').first; // e.g. "Feb"
      onSelect = (item) {
        widget.onFilterChanged(selectedMonth: item as String);
      };
    } else {
      // বাৎসরিক
      items = _years;
      selectedValue = widget.selectedYear;
      labelMapper = (item) => (item as String);
      onSelect = (item) {
        widget.onFilterChanged(selectedYear: item as String);
      };
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      height: 35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, 
        children: [
          if (widget.selectedPeriod == 'দৈনিক')
            IconButton(
              icon: Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary, size: 18),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  widget.onFilterChanged(selectedDate: picked);
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
                
                if (widget.selectedPeriod == 'দৈনিক') {
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

  Widget _buildSummaryCards() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              label: l10n.income,
              amount: '৳${context.l10n.formatAmount(_totalAdded)}',
              amountColor: colorScheme.onSurface,
              icon: Icons.arrow_downward,
              iconColor: colorScheme.primary,
              iconBackgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
              onTap: () => _showTransactionDialog(context, 'income'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: l10n.expenseLabel,
              amount: '৳${context.l10n.formatAmount(_totalExpense)}',
              amountColor: colorScheme.onSurface,
              icon: Icons.arrow_upward,
              iconColor: colorScheme.error,
              iconBackgroundColor: colorScheme.error.withValues(alpha: 0.15),
              onTap: () => _showTransactionDialog(context, 'expense'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: l10n.report,
              amount: 'PDF',
              amountColor: colorScheme.primary,
              icon: Icons.picture_as_pdf_outlined,
              iconColor: colorScheme.primary,
              iconBackgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
              onTap: () => _generateExpenseReport(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.primary, width: 1),
        ),
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          Tab(text: '    ${l10n.all}    '),
          Tab(text: '    ${l10n.income}    '),
          Tab(text: '    ${l10n.expenseLabel}    '),
        ],
      ),
    );
  }

  Widget _buildTabTransactionsList(String? filterType) {
    List<ShopTransaction> filteredTransactions;
    if (filterType == null) {
      filteredTransactions = _transactions;
    } else {
      filteredTransactions = _transactions.where((t) => t.transactionType == filterType).toList();
    }

    if (filteredTransactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400, // Approximate height for empty state
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: _buildTransactionsList(filteredTransactions),
    );
  }

  Widget _buildTransactionsList(List<ShopTransaction> transactions) {
    // Group transactions by date
    final grouped = <String, List<ShopTransaction>>{};
    for (final trans in transactions) {
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
            Builder(
              builder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: cs.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateKey,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'মোট ${dayTotal >= 0 ? '+' : '-'}৳${context.l10n.formatAmount(dayTotal.abs())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: dayTotal >= 0 ? cs.primary : cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: dayTransactions.map((transaction) {
                  return TransactionItem(
                    transaction: transaction,
                    onTap: () => _showEditTransactionDialog(context, transaction),
                  );
                }).toList(),
              ),
            ),
            Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.outlineVariant),
          ],
        );
      },
    );
  }

  Future<void> _generateExpenseReport() async {
    // Calculate date range based on current filter
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();
    String dateLabel = '';

    switch (widget.selectedPeriod) {
      case 'দৈনিক':
        startDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
        endDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
        dateLabel = DateFormat('dd MMM yyyy').format(widget.selectedDate);
        break;
      case 'মাসিক':
        final parsedMonth = DateFormat('MMM yyyy').parse(widget.selectedMonth);
        startDate = DateTime(parsedMonth.year, parsedMonth.month, 1);
        endDate = DateTime(parsedMonth.year, parsedMonth.month + 1, 0, 23, 59, 59);
        dateLabel = widget.selectedMonth;
        break;
      case 'বাৎসরিক':
        final yearNum = int.parse(widget.selectedYear);
        startDate = DateTime(yearNum, 1, 1);
        endDate = DateTime(yearNum, 12, 31, 23, 59, 59);
        dateLabel = widget.selectedYear;
        break;
      case 'পরিসর':
        if (widget.customDateRange != null) {
          startDate = widget.customDateRange!.start;
          endDate = widget.customDateRange!.end;
          dateLabel = '${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
        }
        break;
    }

    final html = StringBuffer();
    html.writeln('''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Hind+Siliguri:wght@400;700&display=swap');
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Hind Siliguri', sans-serif; padding: 40px; font-size: 14px; color: #333; line-height: 1.4; }
  .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; }
  .shop-info h1 { font-size: 24px; color: #000; margin-bottom: 4px; }
  .brand { display: flex; align-items: center; color: #00695C; font-weight: bold; font-size: 20px; }
  .brand-icon { width: 24px; height: 24px; background: #00695C; margin-right: 8px; border-radius: 4px; }
  .report-box { border: 1px solid #E0E0E0; border-radius: 8px; margin-bottom: 20px; overflow: hidden; }
  .report-header { background: #fff; padding: 15px 20px; border-bottom: 1px solid #E0E0E0; display: flex; justify-content: space-between; align-items: center; }
  .report-title { font-size: 18px; font-weight: bold; }
  .totals-column { text-align: right; }
  .total-row { display: flex; justify-content: flex-end; margin-bottom: 4px; font-size: 13px; }
  .total-label { color: #666; margin-right: 15px; }
  .total-value { font-weight: bold; width: 100px; }
  .meta-info { display: flex; justify-content: space-between; font-size: 12px; color: #777; margin-bottom: 10px; padding: 0 5px; }
  table { width: 100%; border-collapse: collapse; border: 1px solid #E0E0E0; }
  th { background: #F5F5F5; color: #666; font-weight: bold; text-align: left; padding: 10px; font-size: 12px; border-bottom: 1px solid #E0E0E0; }
  td { padding: 10px; font-size: 12px; border-bottom: 1px solid #F0F0F0; }
  tr:last-child td { border-bottom: none; }
  .text-right { text-align: right; }
  .text-green { color: #2e7d32; font-weight: bold; }
  .text-red { color: #c62828; font-weight: bold; }
</style>
</head>
<body>
  <div class="header">
    <div class="shop-info">
      <h1>আমার দোকান</h1>
      <p>খরচের হিসাব</p>
    </div>
    <div class="brand">
      <div class="brand-icon"></div>
      Amar Dokan
    </div>
  </div>
  <div class="report-box">
    <div class="report-header">
      <div class="report-title">খরচের রিপোর্ট ($dateLabel)</div>
      <div class="totals-column">
        <div class="total-row">
          <span class="total-label">মোট জমা:</span>
          <span class="total-value text-green">৳ ${_totalAdded.toStringAsFixed(0)}</span>
        </div>
        <div class="total-row">
          <span class="total-label">মোট খরচ:</span>
          <span class="total-value text-red">৳ ${_totalExpense.toStringAsFixed(0)}</span>
        </div>
        <div class="total-row">
          <span class="total-label">ব্যালেন্স:</span>
          <span class="total-value" style="color: ${(_totalAdded - _totalExpense) >= 0 ? '#2e7d32' : '#c62828'};">৳ ${(_totalAdded - _totalExpense).toStringAsFixed(0)}</span>
        </div>
      </div>
    </div>
  </div>
  <div class="meta-info">
    <span>মোট লেনদেন: ${_transactions.length} টি</span>
    <span>রিপোর্ট তৈরী: ${DateFormat('dd MMM yyyy • hh:mm a').format(now)}</span>
  </div>
  <table>
    <thead>
      <tr>
        <th>তারিখ</th>
        <th>খাত</th>
        <th>বিবরণ</th>
        <th>ধরণ</th>
        <th class="text-right">পরিমাণ</th>
      </tr>
    </thead>
    <tbody>
''');

    for (final t in _transactions) {
      final isIncome = t.transactionType == 'income';
      final escapedCategory = (t.category ?? '-').replaceAll('&', '&amp;').replaceAll('<', '&lt;');
      final escapedDesc = (t.description ?? '-').replaceAll('&', '&amp;').replaceAll('<', '&lt;');
      html.writeln('''
      <tr>
        <td>${DateFormat('dd/MM/yy').format(t.transactionDate)}</td>
        <td>$escapedCategory</td>
        <td>$escapedDesc</td>
        <td>${isIncome ? 'জমা' : 'খরচ'}</td>
        <td class="text-right ${isIncome ? 'text-green' : 'text-red'}">${isIncome ? '+' : '-'}৳ ${t.amount.toStringAsFixed(0)}</td>
      </tr>
''');
    }

    html.writeln('''
    </tbody>
  </table>
</body>
</html>
''');

    await Printing.layoutPdf(
      onLayout: (format) => Printing.convertHtml(format: format, html: html.toString()),
      name: 'Expense_Report_${DateFormat('dd_MMM_yyyy').format(now)}.pdf',
    );
  }

  Widget _buildFABs() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'expense',
          backgroundColor: const Color(0xFFF44336),
          onPressed: () => _showTransactionDialog(context, 'expense'),
          icon: const Icon(Icons.remove, color: Colors.white, size: 20),
          label: Text(context.l10n.expenseLabel, style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'income',
          backgroundColor: const Color(0xFF4CAF50),
          onPressed: () => _showTransactionDialog(context, 'income'),
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: Text(context.l10n.income, style: const TextStyle(color: Colors.white)),
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
            _searchQuery.isNotEmpty || widget.selectedPeriod != 'মাসিক'
                ? Icons.search_off
                : Icons.history, 
            size: 64, 
            color: Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || widget.selectedPeriod != 'মাসিক'
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
                        '৳${context.l10n.formatAmount(trans.amount)}',
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
