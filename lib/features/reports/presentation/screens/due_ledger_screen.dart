import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/constants/database_constants.dart';
import '../../data/report_repository.dart';
import '../../domain/due_ledger_model.dart';
import '../../services/report_generator.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../main.dart';
import '../widgets/month_selector.dart';
import '../widgets/summary_card.dart';

class DueLedgerScreen extends StatelessWidget {
  const DueLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class DueLedgerView extends StatefulWidget {
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

  const DueLedgerView({
    super.key,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.selectedMonth,
    required this.selectedYear,
    this.customDateRange,
    required this.onFilterChanged,
  });

  @override
  State<DueLedgerView> createState() => _DueLedgerViewState();
}

class _DueLedgerViewState extends State<DueLedgerView> with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  List<CustomerDue> _allCustomers = [];
  List<CustomerDue> _filteredCustomers = [];

  List<CustomerDue> _customersList = [];
  List<CustomerDue> _suppliersList = [];
  Map<String, dynamic> _summary = {
    'totalReceivable': 0.0,
    'totalCollected': 0.0,
    'totalPayable': 0.0,
    'totalPaid': 0.0,
  };
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name_asc';
  Timer? _debounce;

  final List<DateTime> _days = [];
  final List<String> _months = [];
  final List<String> _years = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _generateLists();
    _loadData();
  }

  @override
  void didUpdateWidget(DueLedgerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear ||
        oldWidget.customDateRange != widget.customDateRange) {
      _loadData();
    }
  }

  void _generateLists() {
    final now = DateTime.now();

    _days.clear();
    for (int i = 0; i < 30; i++) {
      _days.add(now.subtract(Duration(days: i)));
    }

    _months.clear();
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      _months.add(DateFormat('MMM yyyy').format(date));
    }

    _years.clear();
    for (int i = 0; i < 10; i++) {
      _years.add((now.year - i).toString());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as ModalRoute<void>);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  DateTime? get _startDate {
    switch (widget.selectedPeriod) {
      case 'দৈনিক':
        return DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
      case 'মাসিক':
        final parsedMonth = DateFormat('MMM yyyy').parse(widget.selectedMonth);
        return DateTime(parsedMonth.year, parsedMonth.month, 1);
      case 'বাৎসরিক':
        final yearNum = int.parse(widget.selectedYear);
        return DateTime(yearNum, 1, 1);
      case 'পরিসর':
        return widget.customDateRange?.start;
      default:
        return null;
    }
  }

  DateTime? get _endDate {
    switch (widget.selectedPeriod) {
      case 'দৈনিক':
        return DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
      case 'মাসিক':
        final parsedMonth = DateFormat('MMM yyyy').parse(widget.selectedMonth);
        return DateTime(parsedMonth.year, parsedMonth.month + 1, 0, 23, 59, 59);
      case 'বাৎসরিক':
        final yearNum = int.parse(widget.selectedYear);
        return DateTime(yearNum, 12, 31, 23, 59, 59);
      case 'পরিসর':
        return widget.customDateRange?.end;
      default:
        return null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());

    final summary = await repo.getBakirKhataSummary();
    final customers = await repo.getFilteredCustomers(
      searchQuery: _searchController.text,
      startDate: _startDate,
      endDate: _endDate,
    );

    setState(() {
      _summary = summary;
      _allCustomers = customers;
      _customersList = customers.where((c) => c.type == 'customer').toList();
      _suppliersList = customers.where((c) => c.type == 'supplier').toList();
      _applyTabFilter();
      _isLoading = false;
    });
  }

  void _applyTabFilter() {
    setState(() {
      if (_tabController.index == 0) {
        _filteredCustomers = List.from(_customersList);
      } else {
        _filteredCustomers = List.from(_suppliersList);
      }
      _sortCustomers();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData();
    });
  }

  void _sortCustomers() {
    setState(() {
      switch (_sortBy) {
        case 'name_asc':
          _filteredCustomers.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'name_desc':
          _filteredCustomers.sort((a, b) => b.name.compareTo(a.name));
          break;
        case 'balance_asc':
          _filteredCustomers.sort((a, b) => a.currentCreditBalance.compareTo(b.currentCreditBalance));
          break;
        case 'balance_desc':
          _filteredCustomers.sort((a, b) => b.currentCreditBalance.compareTo(a.currentCreditBalance));
          break;
        case 'last_transaction':
          _filteredCustomers.sort((a, b) {
            if (a.lastTransactionDate == null) return 1;
            if (b.lastTransactionDate == null) return -1;
            return b.lastTransactionDate!.compareTo(a.lastTransactionDate!);
          });
          break;
      }
    });
  }

  void _resetFilters() {
    _searchController.clear();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            _buildPeriodTabs(),
            _buildCurrentSelectionSelector(),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: _buildTabSummaryCard(isCustomer: _tabController.index == 0),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSearchBar(),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      floating: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 48,
                        maxHeight: 48,
                        child: _buildDueTabBar(),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabContent(isCustomer: true),
                    _buildTabContent(isCustomer: false),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddCustomerDialog(isSupplier: _tabController.index == 1),
          icon: const Icon(Icons.person_add_outlined, size: 20),
          label: Text(context.l10n.addNew, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
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
      labelMapper = (item) => (item as String).split(' ').first;
      onSelect = (item) {
        widget.onFilterChanged(selectedMonth: item as String);
      };
    } else {
      items = _years;
      selectedValue = widget.selectedYear;
      labelMapper = (item) => (item as String);
      onSelect = (item) {
        widget.onFilterChanged(selectedYear: item as String);
      };
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      height: 35,
      child: Row(
        children: [
          if (widget.selectedPeriod == 'দৈনিক')
            IconButton(
              icon: Icon(Icons.calendar_month, color: colorScheme.primary, size: 18),
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
              reverse: true,
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

  Widget _buildDueTabBar() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          Tab(text: '  ${l10n.customer}  '),
          Tab(text: '  ${l10n.supplier}  '),
        ],
      ),
    );
  }

  List<CustomerDue> _getFilteredList(bool isCustomer) {
    final list = isCustomer ? _customersList : _suppliersList;
    final search = _searchController.text.toLowerCase();
    return list.where((c) =>
      c.name.toLowerCase().contains(search) ||
      (c.phone != null && c.phone!.contains(search))
    ).toList();
  }

  Widget _buildTabContent({required bool isCustomer}) {
    final filteredList = _getFilteredList(isCustomer);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredList.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    return _buildCustomerList(filteredList);
  }

  Widget _buildTabSummaryCard({required bool isCustomer}) {
    // Compute totals from filtered list
    final list = isCustomer ? _customersList : _suppliersList;
    double total = 0;
    double paid = 0;
    for (final c in list) {
      total += c.currentCreditBalance;
      paid += c.totalPaid;
    }

    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final labelTotal = isCustomer ? l10n.totalReceive : l10n.totalPay;
    final labelPaid = isCustomer ? l10n.collectedLabel : l10n.paidLabel;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              label: labelTotal,
              amount: '৳${l10n.formatAmount(total)}',
              amountColor: colorScheme.onSurface,
              icon: isCustomer ? Icons.arrow_downward : Icons.arrow_upward,
              iconColor: isCustomer ? colorScheme.tertiary : colorScheme.primary,
              iconBackgroundColor: (isCustomer ? colorScheme.tertiary : colorScheme.primary).withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: labelPaid,
              amount: '৳${l10n.formatAmount(paid)}',
              amountColor: colorScheme.onSurface,
              icon: Icons.check_circle_outline,
              iconColor: colorScheme.primary,
              iconBackgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: l10n.report,
              amount: 'PDF',
              amountColor: colorScheme.primary,
              icon: Icons.picture_as_pdf_outlined,
              iconColor: colorScheme.error,
              iconBackgroundColor: colorScheme.error.withValues(alpha: 0.15),
              onTap: () => _generateAndSharePDF(isCustomer: isCustomer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: context.l10n.searchCustomer,
                prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _resetFilters,
                    )
                  : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildFilterButton(Icons.sort, () => _showSortOptions()),
        ],
      ),
    );
  }

  Widget _buildFilterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(context.l10n.sortBy, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _buildSortItem(context.l10n.sortNameAZ, 'name_asc'),
          _buildSortItem(context.l10n.sortNameZA, 'name_desc'),
          _buildSortItem(context.l10n.sortDueHighToLow, 'balance_desc'),
          _buildSortItem(context.l10n.sortDueLowToHigh, 'balance_asc'),
          _buildSortItem(context.l10n.sortByLastTransaction, 'last_transaction'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSortItem(String title, String value) {
    final isSelected = _sortBy == value;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(title, style: TextStyle(color: isSelected ? colorScheme.primary : colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check, color: colorScheme.primary) : null,
      onTap: () {
        setState(() => _sortBy = value);
        _sortCustomers();
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCustomerList(List<CustomerDue> customers) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return _buildCustomerDueItem(customer);
        },
      ),
    );
  }

  Widget _buildCustomerDueItem(CustomerDue customer) {
    final isCustomer = customer.type == 'customer';
    final colorScheme = Theme.of(context).colorScheme;
    final amountColor = isCustomer ? colorScheme.error : colorScheme.primary;
    final iconBgColor = isCustomer ? colorScheme.error.withValues(alpha: 0.15) : colorScheme.primaryContainer.withValues(alpha: 0.3);
    final iconColor = isCustomer ? colorScheme.tertiary : colorScheme.primary;

    return Dismissible(
      key: Key('customer_${customer.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (customer.currentCreditBalance > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.cannotDeleteCustomerWithDue), backgroundColor: Colors.red),
          );
          return false;
        }
        return await _showDeleteConfirmation(customer);
      },
      onDismissed: (direction) => _deleteCustomer(customer.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete, color: Colors.white),
            Text(context.l10n.delete, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      child: Builder(
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return InkWell(
            onTap: () => _showCustomerMenu(context, customer),
            child: Container(
              color: cs.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0] : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 12, color: cs.outline),
                            const SizedBox(width: 4),
                            Text(
                              customer.phone ?? context.l10n.noPhone,
                              style: TextStyle(fontSize: 12, color: cs.outline),
                            ),
                            if (customer.lastTransactionDate != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.calendar_today, size: 12, color: cs.outline),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM').format(customer.lastTransactionDate!),
                                style: TextStyle(fontSize: 12, color: cs.outline),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '৳${context.l10n.formatAmount(customer.currentCreditBalance.abs())}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: cs.outline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Actions ---

  Future<void> _generateAndSharePDF({bool isCustomer = true}) async {
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());

    Map<int, List<CustomerTransaction>> histories = {};
    for (var c in _filteredCustomers) {
      histories[c.id] = await repo.getCustomerTransactionHistory(c.id);
    }

    await ReportGenerator.generateBakirKhataPDF(
      shopName: context.l10n.shopNameForReport,
      summary: _summary,
      customers: _filteredCustomers,
      transactionHistories: histories,
      startDate: _startDate,
      endDate: _endDate,
      reportType: _tabController.index == 0 ? context.l10n.customer : context.l10n.supplier,
    );
  }

  Future<void> _deleteCustomer(int id) async {
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
    await repo.deleteCustomer(id);
    _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.customerDeleted)));
  }

  Future<bool?> _showDeleteConfirmation(CustomerDue customer) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.warning),
        content: Text('${context.l10n.deleteCustomerConfirm}\n\n${context.l10n.name}: ${customer.name}\n${context.l10n.due}: ৳${context.l10n.formatAmount(customer.currentCreditBalance)}\n\n${context.l10n.allTransactionsDeletedWarning}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.deleteConfirm, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
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
            leading: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
            title: Text(context.l10n.editCustomerInfo),
            onTap: () {
              Navigator.pop(context);
              _showEditCustomerDialog(customer);
            },
          ),
          ListTile(
            leading: Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary),
            title: Text(context.l10n.recordPayment),
            subtitle: Text(context.l10n.recordPaymentSubtitle),
            onTap: () {
              Navigator.pop(context);
              _showPaymentCollectionDialog(context, customer);
            },
          ),
          ListTile(
            leading: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
            title: Text(context.l10n.transactionHistory),
            onTap: () {
              Navigator.pop(context);
              _showTransactionHistorySheet(context, customer);
            },
          ),
          ListTile(
            leading: Icon(Icons.call_outlined, color: Theme.of(context).colorScheme.tertiary),
            title: Text(context.l10n.contact),
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

  void _showEditCustomerDialog(CustomerDue customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final addressController = TextEditingController(text: customer.address);
    final notesController = TextEditingController(text: customer.notes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.editCustomer),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: context.l10n.nameRequiredLabel)),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.l10n.phoneRequiredLabel)),
              TextField(controller: addressController, decoration: InputDecoration(labelText: context.l10n.addressOptional)),
              TextField(controller: notesController, decoration: InputDecoration(labelText: context.l10n.commentOptional)),
              const SizedBox(height: 16),
              Text('${context.l10n.currentDue}: ৳${context.l10n.formatAmount(customer.currentCreditBalance)}',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.namePhoneRequiredError)));
                return;
              }

              final updated = CustomerDue(
                id: customer.id,
                name: nameController.text,
                phone: phoneController.text,
                address: addressController.text,
                notes: notesController.text,
                type: customer.type,
                currentCreditBalance: customer.currentCreditBalance,
                totalCredit: customer.totalCredit,
                totalPaid: customer.totalPaid,
                totalPurchases: customer.totalPurchases,
              );

              final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
              await repo.updateCustomer(updated);

              if (!mounted) return;
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.customerUpdated)));
            },
            child: Text(context.l10n.save),
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
          Icon(Icons.check_circle_outline, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(context.l10n.noCustomersFound, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showAddCustomerDialog({bool isSupplier = false}) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    String customerType = isSupplier ? 'supplier' : 'customer';
    final l10n = (context).l10n;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isSupplier ? l10n.newSupplier : l10n.newCustomer),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: customerType,
                  decoration: InputDecoration(labelText: l10n.type),
                  items: [
                    DropdownMenuItem(value: 'customer', child: Text(context.l10n.customerReceivable)),
                    DropdownMenuItem(value: 'supplier', child: Text(context.l10n.supplierPayable)),
                  ],
                  onChanged: (val) => setState(() => customerType = val!),
                ),
                TextField(controller: nameController, decoration: InputDecoration(labelText: context.l10n.nameRequiredLabel)),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.l10n.phoneRequiredLabel)),
                TextField(controller: addressController, decoration: InputDecoration(labelText: context.l10n.addressOptional)),
                TextField(controller: notesController, decoration: InputDecoration(labelText: context.l10n.commentOptional)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.namePhoneRequiredError)));
                return;
              }

                final db = context.read<DatabaseHelper>();
                final database = await db.database;

                await database.insert(DatabaseConstants.tableCustomers, {
                  DatabaseConstants.colName: nameController.text,
                  DatabaseConstants.colPhone: phoneController.text,
                  DatabaseConstants.colAddress: addressController.text,
                  DatabaseConstants.colNotes: notesController.text,
                  DatabaseConstants.colCustomerType: customerType,
                  DatabaseConstants.colCurrentCreditBalance: 0.0,
                  DatabaseConstants.colTotalCredit: 0.0,
                  DatabaseConstants.colTotalPaid: 0.0,
                  DatabaseConstants.colTotalPurchases: 0.0,
                  DatabaseConstants.colIsActive: 1,
                  DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
                  DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
                  DatabaseConstants.colIsSynced: 0,
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.customerAdded)));
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentCollectionDialog(BuildContext context, CustomerDue customer) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.collectMoney),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${context.l10n.customer}: ${customer.name}'),
            const SizedBox(height: 8),
            Text('${context.l10n.currentDue}: ৳${context.l10n.formatAmount(customer.currentCreditBalance)}',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.l10n.amountToCollect, prefixText: '৳', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: context.l10n.noteOptional, border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.enterCorrectAmount)));
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
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.moneyCollectionSuccess)));
            },
            child: Text(context.l10n.confirm),
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
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.transactionHistory, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text(context.l10n.formatDigits(customer.name), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                        ],
                      ),
                      const Spacer(),
                      Text(context.l10n.formatAmount(customer.totalCredit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: history.isEmpty
                      ? Center(child: Text(context.l10n.noTransactionHistory))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: history.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final trans = history[index];
                            final isSale = trans.transactionType == 'sale';
                            return ListTile(
                              title: Text(isSale ? context.l10n.productPurchaseDue : context.l10n.payMoney),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (trans.description != null) Text(trans.description!, style: const TextStyle(fontSize: 12)),
                                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(trans.transactionDate),
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isSale ? "+" : "-"} ৳${context.l10n.formatAmount(trans.amount)}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isSale ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                                  ),
                                  Text('${context.l10n.balance} ৳${context.l10n.formatAmount(trans.balanceAfter)}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
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
            leading: Icon(Icons.call, color: Theme.of(context).colorScheme.primary),
            title: Text(context.l10n.call),
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
            leading: Icon(Icons.message, color: Theme.of(context).colorScheme.primary),
            title: Text(context.l10n.sendSms),
            onTap: () async {
              final url = 'sms:${customer.phone}?body=${context.l10n.yourShopDueMessage} ৳${customer.currentCreditBalance} ${context.l10n.paymentRequestMessage}';
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
