import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
    String label = 'সব';

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

  String _toBengaliDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], bengali[i]);
    }
    return input;
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
          HapticFeedback.heavyImpact();
          _showSaleSuccessDialog(context, state.sale);
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
              label: const Text('নতুন বিক্রি'),
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
              child: const Text('পুনরায় চেষ্টা করুন'),
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
                      child: _buildSummaryCards(state),
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
                    _buildHistoryList(state, 'all'),
                    _buildHistoryList(state, 'cash'),
                    _buildHistoryList(state, 'credit'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const Center(child: Text('বিক্রয় ডাটা লোড করা যাচ্ছে না'));
  }

  Widget _buildPeriodTabs() {
    return Container(
      color: Colors.white,
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
    final isSelected = widget.selectedPeriod == label;
    return GestureDetector(
      onTap: () async {
        if (label == 'পরিসর') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            widget.onFilterChanged(
              selectedPeriod: label,
              customDateRange: picked,
            );
          }
        } else {
          widget.onFilterChanged(selectedPeriod: label);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

    return Container(
      color: Colors.white,
      height: 35,
      child: Row(
        children: [
          if (widget.selectedPeriod == 'দৈনিক')
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Color(0xFF2196F3), size: 18),
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

  Widget _buildSummaryCards(SalesDataLoaded state) {
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

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SummaryCard(
              label: 'মোট বিক্রি',
              amount: '৳${DateFormatterUtils.toBengaliNumber(totalSales)}',
              amountColor: const Color(0xFF212121),
              icon: Icons.shopping_cart,
              iconColor: const Color(0xFF1976D2),
              iconBackgroundColor: const Color(0xFFE3F2FD),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: 'বাকি বিক্রি',
              amount: '৳${DateFormatterUtils.toBengaliNumber(totalCredit)}',
              amountColor: const Color(0xFF212121),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFFFF9800),
              iconBackgroundColor: const Color(0xFFFFF3E0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryCard(
              label: 'রিপোর্ট',
              amount: 'PDF',
              amountColor: const Color(0xFF2196F3),
              icon: Icons.picture_as_pdf_outlined,
              iconColor: const Color(0xFFF44336),
              iconBackgroundColor: const Color(0xFFFFEBEE),
              onTap: () {
                ReportGenerator.generateSalesPDF(
                  shopName: 'আমার দোকান',
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
                hintText: 'ইনভয়েস বা গ্রাহক খুঁজুন...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildHistoryTabs(SalesDataLoaded state) {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const TabBar(
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Color(0xFFBBDEFB),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        labelColor: Color(0xFF1976D2),
        unselectedLabelColor: Color(0xFF757575),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          Tab(text: '     সব     '),
          Tab(text: '     নগদ     '),
          Tab(text: '     বাকি     '),
        ],
      ),
    );
  }

  Widget _buildHistoryList(SalesDataLoaded state, String type) {
    final sales = type == 'all'
        ? state.salesHistory
        : state.salesHistory.where((s) => s.paymentMethod == type).toList();

    if (sales.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<SalesBloc>().add(LoadSalesInitialData());
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('কোনো বিক্রয় তথ্য পাওয়া যায়নি', style: TextStyle(color: Colors.grey.shade500)),
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
        context.read<SalesBloc>().add(LoadSalesInitialData());
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: dateKeys.length,
        itemBuilder: (context, index) {
          final dateKey = dateKeys[index];
          final daySales = grouped[dateKey]!;

          double dayTotal = 0;
          for (var s in daySales) {
            dayTotal += s.totalAmount;
          }

          return Column(
            children: [
              // Date header
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
                      'মোট ৳${DateFormatterUtils.toBengaliNumber(dayTotal)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Day's transactions
              Container(
                color: Colors.white,
                child: Column(
                  children: daySales.map((sale) {
                    final isCash = sale.paymentMethod == 'cash';
                    return InkWell(
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isCash ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCash ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                                color: isCash ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sale.productNames ?? 'অজানা পণ্য',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF212121),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 12, color: Color(0xFF9E9E9E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormatterUtils.formatTime(sale.saleDate),
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.receipt_long_outlined, size: 12, color: Color(0xFF9E9E9E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '#${_toBengaliDigits(sale.invoiceId.split('-').last)}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                                      ),
                                    ],
                                  ),
                                  if (!isCash && sale.customerName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      sale.customerName!,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '৳${DateFormatterUtils.toBengaliNumber(sale.totalAmount)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isCash ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isCash ? 'নগদ' : 'বাকি',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isCash ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('সাজান (Sort By)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _buildSortItem(context, 'সর্বশেষ থেকে পুরাতন', 'date_desc', state.sortBy == 'date_desc'),
          _buildSortItem(context, 'পুরাতন থেকে সর্বশেষ', 'date_asc', state.sortBy == 'date_asc'),
          _buildSortItem(context, 'টাকার অঙ্ক (বেশি থেকে কম)', 'amount_desc', state.sortBy == 'amount_desc'),
          _buildSortItem(context, 'টাকার অঙ্ক (কম থেকে বেশি)', 'amount_asc', state.sortBy == 'amount_asc'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSortItem(BuildContext context, String title, String value, bool isSelected) {
    return ListTile(
      title: Text(title, style: TextStyle(color: isSelected ? Colors.blue : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 14, color: Colors.white),
                SizedBox(width: 8),
                Text('অফলাইন মোডে বিক্রয় - ডেটা পরবর্তীতে সিঙ্ক হবে', style: TextStyle(color: Colors.white, fontSize: 12)),
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
        title: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 10),
              Text('বিক্রয় সফল হয়েছে!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDataRow('ইনভয়েস:', _toBengaliDigits(sale.invoiceId)),
            _buildDataRow('মোট পরিমাণ:', '৳${_toBengaliDigits(sale.totalAmount.toStringAsFixed(0))}'),
            _buildDataRow('পেমেন্ট:', sale.paymentMethod == 'cash' ? 'নগদ' : 'বাকি'),
            const Divider(),
            const SizedBox(height: 10),
            _buildActionTile(Icons.print, 'প্রিন্ট রসিদ', Colors.blue, () => InvoiceService.printReceipt(sale)),
            _buildActionTile(Icons.share, 'রসিদ শেয়ার করুন', Colors.green, () => InvoiceService.shareReceipt(sale)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
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
