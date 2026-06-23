import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:amar_dokan/core/l10n/app_localizations.dart';
import 'package:amar_dokan/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:amar_dokan/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:amar_dokan/features/sales/domain/sale.dart';
import 'package:amar_dokan/core/services/invoice_service.dart';
import 'package:amar_dokan/features/reports/presentation/bloc/report_bloc.dart';
import 'package:amar_dokan/features/reports/services/report_generator.dart';
import 'package:amar_dokan/features/dashboard/presentation/bloc/home_bloc.dart';
import 'package:amar_dokan/core/services/connectivity_service.dart';
import 'package:amar_dokan/features/reports/presentation/widgets/summary_card.dart';
import 'package:amar_dokan/features/reports/presentation/widgets/month_selector.dart';
import 'package:amar_dokan/features/reports/utils/date_formatter_utils.dart';
import '../widgets/sale_form_bottom_sheet.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class SalesView extends StatefulWidget {
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

  const SalesView({
    super.key,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.selectedMonth,
    required this.selectedYear,
    this.customDateRange,
    required this.onFilterChanged,
  });

  @override
  State<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<SalesView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<DateTime> _days = [];
  final List<String> _months = [];
  final List<String> _years = [];

  @override
  void initState() {
    super.initState();
    _generateLists();
    _applyPeriodFilter();
  }

  @override
  void didUpdateWidget(SalesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear ||
        oldWidget.customDateRange != widget.customDateRange) {
      _applyPeriodFilter();
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

  void _applyPeriodFilter() {
    DateTime? start;
    DateTime? end;
    // Do not use context.l10n here - this can be called from initState before inherited widgets are available.
    String label = 'All';

    switch (widget.selectedPeriod) {
      case 'দৈনিক':
        start = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
        end = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
        label = DateFormat('dd MMM yyyy').format(widget.selectedDate);
        break;
      case 'মাসিক':
        final parsedMonth = DateFormat('MMM yyyy').parse(widget.selectedMonth);
        start = DateTime(parsedMonth.year, parsedMonth.month, 1);
        end = DateTime(parsedMonth.year, parsedMonth.month + 1, 0, 23, 59, 59);
        label = widget.selectedMonth;
        break;
      case 'বাৎসরিক':
        final yearNum = int.parse(widget.selectedYear);
        start = DateTime(yearNum, 1, 1);
        end = DateTime(yearNum, 12, 31, 23, 59, 59);
        label = widget.selectedYear;
        break;
      case 'পরিসর':
        if (widget.customDateRange != null) {
          start = widget.customDateRange!.start;
          end = widget.customDateRange!.end;
          label = '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
        }
        break;
    }

    context.read<SalesBloc>().add(UpdateSalesFilters(
      startDate: start,
      endDate: end,
      selectedDateFilterLabel: label,
      clearStartDate: start == null,
      clearEndDate: end == null,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _showSaleFormBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SaleFormBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          context.read<InventoryBloc>().add(LoadProducts());
          context.read<HomeBloc>().add(RefreshDashboard());
          context.read<ReportBloc>().add(RefreshReports());
        } else if (state is SalesError) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'sales_fab',
              onPressed: () => _showSaleFormBottomSheet(context),
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              label: Text(context.l10n.newSale),
            ),
            body: _buildBody(state),
          ),
        );
      },
    );
  }

  Widget _buildBody(SalesState state) {
    if (state is SalesLoading || state is SalesInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is SalesError && state.message.contains('লোড')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<SalesBloc>().add(LoadSalesInitialData()),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    if (state is SalesDataLoaded) {
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            _buildConnectivityBanner(),
            _buildPeriodTabs(),
            _buildCurrentSelectionSelector(),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: _buildSummaryCards(context, state),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSearchBar(state),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 48,
                        maxHeight: 48,
                        child: _buildHistoryTabs(state),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  children: [
                    _buildHistoryList(context, state, 'all'),
                    _buildHistoryList(context, state, 'cash'),
                    _buildHistoryList(context, state, 'credit'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(child: Text(context.l10n.salesDataLoadError));
  }

  Widget _buildPeriodTabs() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
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

  Widget _buildSummaryCards(BuildContext context, SalesDataLoaded state) {
    // Compute totals directly from filtered sales list
    double totalSales = 0;
    double totalCredit = 0;
    for (final sale in state.salesHistory) {
      totalSales += sale.totalAmount;
      if (sale.paymentMethod == 'credit') {
        totalCredit += sale.totalAmount;
      }
    }
    final totalCash = totalSales - totalCredit;

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              label: context.l10n.totalSales,
              amount: '৳${context.l10n.formatAmount(totalSales)}',
              amountColor: colorScheme.onSurface,
              icon: Icons.shopping_cart,
              iconColor: colorScheme.primary,
              iconBackgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: context.l10n.creditSales,
              amount: '৳${context.l10n.formatAmount(totalCredit)}',
              amountColor: colorScheme.onSurface,
              icon: Icons.account_balance_wallet_outlined,
              iconColor: colorScheme.tertiary,
              iconBackgroundColor: colorScheme.tertiary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: context.l10n.report,
              amount: 'PDF',
              amountColor: colorScheme.primary,
              icon: Icons.picture_as_pdf_outlined,
              iconColor: colorScheme.error,
              iconBackgroundColor: colorScheme.error.withValues(alpha: 0.15),
              onTap: () {
                ReportGenerator.generateSalesPDF(
                  shopName: context.l10n.shopNameForReport,
                  sales: state.salesHistory,
                  summary: {'total': totalSales, 'cash': totalCash, 'credit': totalCredit},
                  startDate: state.startDate,
                  endDate: state.endDate,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(SalesDataLoaded state) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                if (_debounce?.isActive ?? false) _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  context.read<SalesBloc>().add(UpdateSalesFilters(searchQuery: v));
                });
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: context.l10n.searchInvoiceOrCustomer,
                prefixIcon: Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<SalesBloc>().add(UpdateSalesFilters(searchQuery: ''));
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.all(0),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outlineVariant)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outlineVariant)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildFilterButton(Icons.sort, () => _showSortOptions(context, state)),
        ],
      ),
    );
  }

  Widget _buildFilterButton(IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildHistoryTabs(SalesDataLoaded state) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TabBar(
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
          Tab(text: '    ${l10n.cash}    '),
          Tab(text: '    ${l10n.credit}    '),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, SalesDataLoaded state, String type) {
    final sales = type == 'all'
        ? state.salesHistory
        : state.salesHistory.where((s) => s.paymentMethod == type).toList();

    if (sales.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          _applyPeriodFilter();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(context.l10n.noSalesData, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Group sales by date
    final grouped = <String, List<Sale>>{};
    for (final sale in sales) {
      final dateKey = DateFormat('dd MMM yyyy').format(sale.saleDate);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(sale);
    }

    final dateKeys = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: () async {
        _applyPeriodFilter();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: dateKeys.length,
        itemBuilder: (context, idx) {
          final dateKey = dateKeys[idx];
          final daySales = grouped[dateKey]!;

          double dayTotal = 0;
          for (var s in daySales) {
            dayTotal += s.totalAmount;
          }

          return Column(
            children: [
              // Date header
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
                          '${context.l10n.totalPrefix} ৳${context.l10n.formatAmount(dayTotal)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Day's transactions
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: daySales.map((sale) {
                    final isCash = sale.paymentMethod == 'cash';
                    return Builder(
                      builder: (ctx) {
                        final cs = Theme.of(ctx).colorScheme;
                        final amountColor = isCash ? cs.primary : cs.tertiary;
                        return InkWell(
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: amountColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isCash ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                                    color: amountColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sale.productNames ?? context.l10n.unknownProduct,
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
                                          Icon(Icons.access_time, size: 12, color: cs.outline),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormatterUtils.formatTime(sale.saleDate),
                                            style: TextStyle(fontSize: 12, color: cs.outline),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.receipt_long_outlined, size: 12, color: cs.outline),
                                          const SizedBox(width: 4),
                                          Text(
                                            '#${context.l10n.formatDigits(sale.invoiceId.split('-').last)}',
                                            style: TextStyle(fontSize: 12, color: cs.outline),
                                          ),
                                        ],
                                      ),
                                      if (!isCash && sale.customerName != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          sale.customerName!,
                                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '৳${context.l10n.formatAmount(sale.totalAmount)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: amountColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isCash ? context.l10n.cash : context.l10n.credit,
                                      style: TextStyle(fontSize: 11, color: amountColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.outlineVariant),
            ],
          );
        },
      ),
    );
  }

  void _showSortOptions(BuildContext context, SalesDataLoaded state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(context.l10n.sortBy, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
          ),
          _buildSortItem(context, context.l10n.sortNewestFirst, 'date_desc', state.sortBy == 'date_desc'),
          _buildSortItem(context, context.l10n.sortOldestFirst, 'date_asc', state.sortBy == 'date_asc'),
          _buildSortItem(context, context.l10n.sortAmountDesc, 'amount_desc', state.sortBy == 'amount_desc'),
          _buildSortItem(context, context.l10n.sortAmountAsc, 'amount_asc', state.sortBy == 'amount_asc'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSortItem(BuildContext context, String title, String value, bool isSelected) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title, style: TextStyle(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      onTap: () {
        context.read<SalesBloc>().add(UpdateSalesFilters(sortBy: value));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildConnectivityBanner() {
    return StreamBuilder<ConnectivityState>(
      stream: context.read<ConnectivityService>().connectivityStream,
      builder: (context, snapshot) {
        if (snapshot.data == ConnectivityState.none) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.orange.shade800,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 14, color: Colors.white),
                const SizedBox(width: 8),
                Text(context.l10n.offlineSalesBanner, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showSaleSuccessDialog(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 10),
              Text(context.l10n.saleSuccess, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDataRow(context.l10n.invoiceColon, context.l10n.formatDigits(sale.invoiceId)),
            _buildDataRow(context.l10n.totalAmountLabel, '৳${context.l10n.formatAmount(sale.totalAmount)}'),
            _buildDataRow(context.l10n.payment, sale.paymentMethod == 'cash' ? context.l10n.cash : context.l10n.credit),
            const Divider(),
            const SizedBox(height: 10),
            _buildActionTile(Icons.print, context.l10n.printReceipt, Colors.blue, () => InvoiceService.printReceipt(sale)),
            _buildActionTile(Icons.share, context.l10n.shareReceipt, Colors.green, () => InvoiceService.shareReceipt(sale)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: EdgeInsets.zero,
      dense: true,
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
