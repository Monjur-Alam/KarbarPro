import 'package:amar_dokan/core/constants/app_colors.dart';
import 'package:amar_dokan/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:amar_dokan/features/dashboard/presentation/bloc/home_bloc.dart';
import 'package:amar_dokan/core/services/sync_service.dart';
import 'package:amar_dokan/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:amar_dokan/features/sales/presentation/screens/sales_screen.dart';
import 'package:amar_dokan/features/reports/presentation/screens/sales_report_screen.dart';
import 'package:amar_dokan/features/reports/presentation/screens/expense_screen.dart';
import '../../../reports/presentation/screens/due_ledger_screen.dart';
import '../../../../core/widgets/navigation_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  
  // Expense Filter state (shared with ExpenseView)
  String _selectedPeriod = 'মাসিক';
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = DateFormat('MMM yyyy').format(DateTime.now());
  String _selectedYear = DateFormat('yyyy').format(DateTime.now());
  DateTimeRange? _customDateRange;

  void updateExpenseFilter({
    String? selectedPeriod,
    DateTime? selectedDate,
    String? selectedMonth,
    String? selectedYear,
    DateTimeRange? customDateRange,
  }) {
    setState(() {
      if (selectedPeriod != null) _selectedPeriod = selectedPeriod;
      if (selectedDate != null) _selectedDate = selectedDate;
      if (selectedMonth != null) _selectedMonth = selectedMonth;
      if (selectedYear != null) _selectedYear = selectedYear;
      if (customDateRange != null) _customDateRange = customDateRange;
    });
  }

  // Sales Filter state (shared with SalesView)
  String _salesSelectedPeriod = 'দৈনিক';
  DateTime _salesSelectedDate = DateTime.now();
  String _salesSelectedMonth = DateFormat('MMM yyyy').format(DateTime.now());
  String _salesSelectedYear = DateFormat('yyyy').format(DateTime.now());
  DateTimeRange? _salesCustomDateRange;

  void updateSalesFilter({
    String? selectedPeriod,
    DateTime? selectedDate,
    String? selectedMonth,
    String? selectedYear,
    DateTimeRange? customDateRange,
  }) {
    setState(() {
      if (selectedPeriod != null) _salesSelectedPeriod = selectedPeriod;
      if (selectedDate != null) _salesSelectedDate = selectedDate;
      if (selectedMonth != null) _salesSelectedMonth = selectedMonth;
      if (selectedYear != null) _salesSelectedYear = selectedYear;
      if (customDateRange != null) _salesCustomDateRange = customDateRange;
    });
  }

  // Due Ledger Filter state (shared with DueLedgerView)
  String _dueSelectedPeriod = 'মাসিক';
  DateTime _dueSelectedDate = DateTime.now();
  String _dueSelectedMonth = DateFormat('MMM yyyy').format(DateTime.now());
  String _dueSelectedYear = DateFormat('yyyy').format(DateTime.now());
  DateTimeRange? _dueCustomDateRange;

  void updateDueFilter({
    String? selectedPeriod,
    DateTime? selectedDate,
    String? selectedMonth,
    String? selectedYear,
    DateTimeRange? customDateRange,
  }) {
    setState(() {
      if (selectedPeriod != null) _dueSelectedPeriod = selectedPeriod;
      if (selectedDate != null) _dueSelectedDate = selectedDate;
      if (selectedMonth != null) _dueSelectedMonth = selectedMonth;
      if (selectedYear != null) _dueSelectedYear = selectedYear;
      if (customDateRange != null) _dueCustomDateRange = customDateRange;
    });
  }

  void setIndex(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    context.read<HomeBloc>().add(LoadDashboard());
    // Auto-refresh summary every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && context.read<HomeBloc>().state is HomeLoaded) {
        final state = context.read<HomeBloc>().state as HomeLoaded;
        context.read<HomeBloc>().add(RefreshDashboard(
          startDate: state.startDate,
          endDate: state.endDate,
        ));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const DashboardHome(),
      SalesView(
        selectedPeriod: _salesSelectedPeriod,
        selectedDate: _salesSelectedDate,
        selectedMonth: _salesSelectedMonth,
        selectedYear: _salesSelectedYear,
        customDateRange: _salesCustomDateRange,
        onFilterChanged: updateSalesFilter,
      ),
      DueLedgerView(
        selectedPeriod: _dueSelectedPeriod,
        selectedDate: _dueSelectedDate,
        selectedMonth: _dueSelectedMonth,
        selectedYear: _dueSelectedYear,
        customDateRange: _dueCustomDateRange,
        onFilterChanged: updateDueFilter,
      ),
      const InventoryScreen(),
      ExpenseView(
        selectedPeriod: _selectedPeriod,
        selectedDate: _selectedDate,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
        customDateRange: _customDateRange,
        onFilterChanged: updateExpenseFilter,
      ),
    ];

    final l10n = context.l10n;
    final List<String> titles = [
      l10n.appTitle,
      l10n.salesTitle,
      l10n.dueLedgerTitle,
      l10n.inventoryTitle,
      l10n.expenseTitle,
    ];
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: _buildAppBar(titles[_selectedIndex], context),
        endDrawer: const AppDrawer(),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            FocusScope.of(context).unfocus();
            setState(() => _selectedIndex = index);
          },
          children: screens,
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title, BuildContext context) {
    String labelText = '';
    if (_selectedIndex == 4) {
      if (_selectedPeriod == 'দৈনিক') {
        labelText = DateFormat('dd MMM yyyy').format(_selectedDate);
      } else if (_selectedPeriod == 'মাসিক') {
        labelText = _selectedMonth;
      } else if (_selectedPeriod == 'বাৎসরিক') {
        labelText = _selectedYear;
      } else if (_selectedPeriod == 'পরিসর' && _customDateRange != null) {
        labelText = '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange!.end)}';
      }
    } else if (_selectedIndex == 1) {
      if (_salesSelectedPeriod == 'দৈনিক') {
        labelText = DateFormat('dd MMM yyyy').format(_salesSelectedDate);
      } else if (_salesSelectedPeriod == 'মাসিক') {
        labelText = _salesSelectedMonth;
      } else if (_salesSelectedPeriod == 'বাৎসরিক') {
        labelText = _salesSelectedYear;
      } else if (_salesSelectedPeriod == 'পরিসর' && _salesCustomDateRange != null) {
        labelText = '${DateFormat('dd MMM').format(_salesCustomDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_salesCustomDateRange!.end)}';
      }
    } else if (_selectedIndex == 2) {
      if (_dueSelectedPeriod == 'দৈনিক') {
        labelText = DateFormat('dd MMM yyyy').format(_dueSelectedDate);
      } else if (_dueSelectedPeriod == 'মাসিক') {
        labelText = _dueSelectedMonth;
      } else if (_dueSelectedPeriod == 'বাৎসরিক') {
        labelText = _dueSelectedYear;
      } else if (_dueSelectedPeriod == 'পরিসর' && _dueCustomDateRange != null) {
        labelText = '${DateFormat('dd MMM').format(_dueCustomDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dueCustomDateRange!.end)}';
      }
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F0F12) : const Color(0xFFF8F9FA);

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      title: _selectedIndex == 0 
        ? _buildHomeTitle(context)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: colorScheme.onSurface),
              ),
              if (labelText.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 10,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      labelText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
      actions: [
        BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            SyncStatus syncStatus = SyncStatus.idle;
            if (state is HomeLoaded) {
              syncStatus = state.syncStatus;
            }
            return _buildSyncIndicator(context, syncStatus);
          },
        ),
        Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTitle(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final hour = DateTime.now().hour;
        String greeting;
        if (hour >= 5 && hour < 12) {
          greeting = l10n.goodMorning;
        } else if (hour >= 12 && hour < 17) {
          greeting = l10n.goodAfternoon;
        } else if (hour >= 17 && hour < 21) {
          greeting = l10n.goodEvening;
        } else {
          greeting = l10n.goodNight;
        }

        DateTime startDate = DateTime.now();
        DateTime endDate = DateTime.now();
        if (state is HomeLoaded) {
          startDate = state.startDate;
          endDate = state.endDate;
        }

        final monthYear = DateFormat('MMMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(startDate);
        final dateLabel = startDate == endDate 
            ? DateFormat('dd MMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(startDate)
            : '${DateFormat('dd MMM', l10n.isBangla ? 'bn_BD' : 'en_US').format(startDate)} - ${DateFormat('dd MMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(endDate)}';

        final isFullMonth = startDate.day == 1 && endDate.day == DateTime(endDate.year, endDate.month + 1, 0).day;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            InkWell(
              onTap: () => _showUnifiedFilter(context, startDate, endDate),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    isFullMonth ? monthYear : dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUnifiedFilter(BuildContext context, DateTime startDate, DateTime endDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UnifiedDashboardFilterSheet(
        initialStartDate: startDate,
        initialEndDate: endDate,
        onRangeSelected: (start, end) {
          context.read<HomeBloc>().add(LoadDashboard(startDate: start, endDate: end));
        },
      ),
    );
  }

  Widget _buildSyncIndicator(BuildContext context, SyncStatus status) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.orange;
        label = l10n.syncSyncing;
        break;
      case SyncStatus.success:
        icon = Icons.cloud_done;
        color = Colors.green;
        label = l10n.syncOnline;
        break;
      case SyncStatus.failed:
        icon = Icons.sync_problem;
        color = Colors.red;
        label = l10n.syncFailed;
        break;
      case SyncStatus.queued:
      case SyncStatus.paused:
        icon = Icons.cloud_off;
        color = Colors.grey;
        label = l10n.syncOffline;
        break;
      case SyncStatus.idle:
        icon = Icons.cloud_queue;
        color = colorScheme.outline;
        label = l10n.syncUsable;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home, color: AppColors.primary),
          label: context.l10n.navHome,
        ),
        NavigationDestination(
          icon: const Icon(Icons.shopping_cart_outlined),
          selectedIcon: const Icon(Icons.shopping_cart, color: AppColors.primary),
          label: context.l10n.navSales,
        ),
        NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book, color: AppColors.primary),
          label: context.l10n.navDueLedger,
        ),
        NavigationDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2, color: AppColors.primary),
          label: context.l10n.navList,
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
          label: context.l10n.navExpense,
        ),
      ],
    );
  }
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<HomeBloc>().add(LoadDashboard());
      },
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          final l10n = context.l10n;

          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HomeLoaded) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildTotalSalesCard(context, state),
                   const SizedBox(height: 16),
                   Row(
                     children: [
                       Expanded(child: _buildBalanceItemCard(
                         context,
                         l10n.totalReceivableLabel,
                         state.summary.totalReceivable,
                         Colors.orange,
                         Icons.handshake_outlined,
                       )),
                       const SizedBox(width: 12),
                       Expanded(child: _buildBalanceItemCard(
                         context,
                         l10n.totalPayableLabel,
                         state.summary.totalPayable,
                         Colors.red,
                         Icons.payments_outlined,
                       )),
                     ],
                   ),
                   const SizedBox(height: 16),
                   _buildCashFlowCard(context, state),
                   const SizedBox(height: 16),
                   _buildSimpleSummaryRow(
                     context,
                     l10n.paidToSupplierLabel, 
                     state.summary.paidToSupplierInPeriod,
                     Colors.blue,
                     Icons.outbox,
                   ),
                   const SizedBox(height: 12),
                   _buildSimpleSummaryRow(
                     context, 
                     l10n.dueCollectionLabel, 
                     state.summary.dueCollectionInPeriod,
                     Colors.green,
                     Icons.assignment_turned_in_outlined,
                   ),
                   const SizedBox(height: 24),
                   _buildReportOptions(context),
                   const SizedBox(height: 24),
                   _buildSectionTitle(context, context.l10n.sectionRecentSales),
                   const SizedBox(height: 12),
                   _buildRecentActivityList(context, state.summary.recentSales),
                   const SizedBox(height: 24),
                   if (state.summary.lowStockProducts.isNotEmpty) ...[
                     _buildSectionTitle(context, context.l10n.sectionLowStock),
                     const SizedBox(height: 12),
                     _buildAlertsSection(context, state.summary.lowStockProducts),
                     const SizedBox(height: 24),
                   ],
                ],
              ),
            );
          } else if (state is HomeError) {
            return Center(child: Text('${context.l10n.errorPrefix}${state.message}'));
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildTotalSalesCard(BuildContext context, HomeLoaded state) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.surfaceContainerHighest, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: const Icon(Icons.receipt_long_outlined, color: Colors.teal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                        l10n.totalSales,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87
                        )
                    ),
                  ],
                ),
                Text('৳${l10n.formatAmount(state.summary.totalAmountToday)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF25252B) : Colors.white70,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.surfaceContainer, width: 1),
            ),
            child: Row(
              children: [
                Expanded(child: _buildSalesBreakdownItem(context, l10n.cash, state.summary.totalSalesCash, const Color(0xFF10B981), Icons.payments_outlined)),
                Container(height: 50, width: 1, color: colorScheme.surfaceContainer, margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(child: _buildSalesBreakdownItem(context, l10n.due, state.summary.totalSalesCredit, Colors.orange, Icons.timer_outlined)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesBreakdownItem(BuildContext context, String label, double amount, Color color, IconData icon) {
    final l10n = context.l10n;
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('৳${l10n.formatAmount(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }

  Widget _buildBalanceItemCard(BuildContext context, String label, double amount, Color iconColor, IconData icon) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.surfaceContainer, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: iconColor),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('৳${l10n.formatAmount(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: iconColor)),
        ],
      ),
    );
  }

  Widget _buildCashFlowCard(BuildContext context, HomeLoaded state) {
    final l10n = context.l10n;
    final cashIn = state.summary.totalManualIncomeInPeriod;
    final cashOut = state.summary.totalManualExpenseInPeriod;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.surfaceContainer, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF25252B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.surfaceContainer),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.cashInHand, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                Text('৳${l10n.formatAmount(state.summary.mainBalance)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6366F1))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCashHalf(
                    context,
                    l10n.cashIn,
                    cashIn,
                    const Color(0xFF10B981), // Emerald/Green
                    Icons.add_circle_outline
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCashHalf(
                    context,
                    l10n.cashOut,
                    cashOut,
                    const Color(0xFFEF4444), // Red
                    Icons.remove_circle_outline
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashHalf(BuildContext context, String label, double amount, Color color, IconData icon) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF25252B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainer),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 8),
              Text('৳${l10n.formatAmount(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReportOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, context.l10n.reportSection),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildReportCard(
              context,
              icon: Icons.receipt_long,
              label: context.l10n.salesReport,
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen())),
            ),
            _buildReportCard(
              context,
              icon: Icons.account_balance_wallet,
              label: context.l10n.expenseReport,
              color: Colors.orange,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<DashboardScreenState>();
                dashboardState?.setIndex(4);
              },
            ),
            _buildReportCard(
              context,
              icon: Icons.inventory_2,
              label: context.l10n.stockReport,
              color: Colors.green,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<DashboardScreenState>();
                dashboardState?.setIndex(3);
              },
            ),
            _buildReportCard(
              context,
              icon: Icons.people,
              label: context.l10n.dueLedgerReport,
              color: Colors.red,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<DashboardScreenState>();
                dashboardState?.setIndex(2);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color.lerp(color, Colors.black, 0.3)!,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleSummaryRow(BuildContext context, String label, double amount, Color color, IconData icon) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainer),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          Text('৳${l10n.formatAmount(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: color)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }


  Widget _buildAlertsSection(BuildContext context, List<Map<String, dynamic>> lowStock) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: lowStock.length,
        itemBuilder: (context, index) {
          final p = lowStock[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                      Text('${context.l10n.stockLabel}: ${context.l10n.formatDigits(p['current_stock'].toString())}', style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivityList(BuildContext context, List<Map<String, dynamic>> sales) {
    final l10n = context.l10n;
    if (sales.isEmpty) {
      return Center(child: Text(l10n.noRecentSales));
    }
    return Column(
      children: sales.map((sale) {
        final date = DateTime.parse(sale['sale_date']);
        final timeStr = context.l10n.formatDigits(DateFormat('hh:mm a').format(date));
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.receipt, color: Colors.blue),
            ),
            title: Text('${l10n.invoiceLabel}: ${l10n.formatDigits(sale['invoice_number'])}'),
            subtitle: Text(timeStr),
            trailing: Text(
              '৳${l10n.formatAmount(sale['total_amount'])}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class UnifiedDashboardFilterSheet extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final Function(DateTime startDate, DateTime endDate) onRangeSelected;

  const UnifiedDashboardFilterSheet({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.onRangeSelected,
  });

  @override
  State<UnifiedDashboardFilterSheet> createState() => _UnifiedDashboardFilterSheetState();
}

class _UnifiedDashboardFilterSheetState extends State<UnifiedDashboardFilterSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _currentStartDate;
  late DateTime _currentEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentStartDate = widget.initialStartDate;
    _currentEndDate = widget.initialEndDate;

    final isFullMonth = _currentStartDate.day == 1 && 
                       _currentEndDate.day == DateTime(_currentEndDate.year, _currentEndDate.month + 1, 0).day;
    if (!isFullMonth) {
      _tabController.index = 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.isBangla ? 'মাস' : 'Month'),
                  Tab(text: l10n.isBangla ? 'তারিখ' : 'Date'),
                ],
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: colorScheme.primary,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMonthTab(scrollController),
                    _buildDateTab(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthTab(ScrollController scrollController) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final List<DateTime> months = [];
    final startDateLimit = DateTime(now.year - 2, now.month);
    final endDateLimit = DateTime(now.year, now.month);

    DateTime current = endDateLimit;
    while (current.isAfter(startDateLimit) || (current.year == startDateLimit.year && current.month == startDateLimit.month)) {
      months.add(DateTime(current.year, current.month));
      current = DateTime(current.year, current.month - 1);
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: months.length,
      itemBuilder: (context, index) {
        final date = months[index];
        final isSelected = date.year == _currentStartDate.year && date.month == _currentStartDate.month &&
                          _currentStartDate.day == 1 && 
                          _currentEndDate.day == DateTime(_currentEndDate.year, _currentEndDate.month + 1, 0).day;

        return ListTile(
          leading: Icon(Icons.calendar_month, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
          title: Text(
            DateFormat('MMMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(date),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
          onTap: () {
            final startOfMonth = DateTime(date.year, date.month, 1);
            final endOfMonth = DateTime(date.year, date.month + 1, 0);
            widget.onRangeSelected(startOfMonth, endOfMonth);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildDateTab(ScrollController scrollController) {
    final l10n = context.l10n;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.isBangla ? 'একটি নির্দিষ্ট তারিখ' : 'Single Date'),
          subtitle: Text(DateFormat('dd MMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(_currentStartDate)),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _currentStartDate.isAfter(DateTime.now()) ? DateTime.now() : _currentStartDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              widget.onRangeSelected(picked, picked);
              Navigator.pop(context);
            }
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.isBangla ? 'তারিখের পরিসর' : 'Date Range'),
          subtitle: Text(
            '${DateFormat('dd MMM', l10n.isBangla ? 'bn_BD' : 'en_US').format(_currentStartDate)} - ${DateFormat('dd MMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(_currentEndDate)}'
          ),
          trailing: const Icon(Icons.date_range),
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(start: _currentStartDate, end: _currentEndDate),
            );
            if (picked != null) {
              widget.onRangeSelected(picked.start, picked.end);
              Navigator.pop(context);
            }
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final today = DateTime.now();
              widget.onRangeSelected(today, today);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.isBangla ? 'আজকের ড্যাশবোর্ড' : 'Today\'s Dashboard'),
          ),
        ),
      ],
    );
  }
}
