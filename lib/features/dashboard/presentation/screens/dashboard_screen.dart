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
      if (mounted) {
        context.read<HomeBloc>().add(RefreshDashboard());
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
    return Scaffold(
      appBar: _buildAppBar(titles[_selectedIndex], context),
      endDrawer: const AppDrawer(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
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
    return AppBar(
      backgroundColor: colorScheme.surface,
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
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
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

        DateTime selectedDate = DateTime.now();
        if (state is HomeLoaded) {
          selectedDate = state.selectedDate;
        }

        final monthYear = DateFormat('MMMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(selectedDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            InkWell(
              onTap: () => _showMonthPickerGlobal(context, selectedDate),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    monthYear,
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

  void _showMonthPickerGlobal(BuildContext context, DateTime initialDate) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return MonthYearPickerSheet(
          initialDate: initialDate,
          onDateSelected: (date) {
            context.read<HomeBloc>().add(LoadDashboard(date: date));
          },
        );
      },
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
                   _buildCashFlowCard(context, state),
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
                   _buildTotalSalesCard(context, state),
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

  Widget _buildCashFlowCard(BuildContext context, HomeLoaded state) {
    final l10n = context.l10n;
    final cashIn = state.summary.totalSalesCash + state.summary.dueCollectionInPeriod;
    final cashOut = state.summary.totalExpense + state.summary.paidToSupplierInPeriod;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
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
                  Icons.arrow_downward
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCashHalf(
                  context, 
                  l10n.cashOut, 
                  cashOut, 
                  const Color(0xFFEF4444), // Red
                  Icons.arrow_upward
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildBalanceItemCard(BuildContext context, String label, double amount, Color iconColor, IconData icon) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
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

  Widget _buildTotalSalesCard(BuildContext context, HomeLoaded state) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
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
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.receipt_long_outlined, color: Colors.teal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.salesTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
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
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _buildSalesBreakdownItem(context, l10n.totalSalesCash, state.summary.totalSalesCash, const Color(0xFF6366F1), Icons.account_balance_wallet)),
                Container(height: 50, width: 1, color: Colors.grey.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(child: _buildSalesBreakdownItem(context, l10n.totalSalesCredit, state.summary.totalSalesCredit, Colors.orange, Icons.timer)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesBreakdownItem(BuildContext context, String label, double amount, Color color, IconData icon) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

  Widget _buildSimpleSummaryRow(BuildContext context, String label, double amount, Color color, IconData icon) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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

class MonthYearPickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const MonthYearPickerSheet({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<MonthYearPickerSheet> {
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    // Generate months for the last 2 years and next 1 month
    final List<DateTime> months = [];
    final startDate = DateTime(now.year - 2, now.month);
    final endDate = DateTime(now.year, now.month);
    final colorScheme = Theme.of(context).colorScheme;

    DateTime current = endDate;
    while (current.isAfter(startDate) || (current.year == startDate.year && current.month == startDate.month)) {
      months.add(DateTime(current.year, current.month));
      current = DateTime(current.year, current.month - 1);
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.selectMonthTitle,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final date = months[index];
                  final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: null,
                      leading: Icon(
                        Icons.calendar_month,
                        color: isSelected ? colorScheme.primary : Colors.grey,
                      ),
                      title: Text(
                        DateFormat('MMMM yyyy', l10n.isBangla ? 'bn_BD' : 'en_US').format(date),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? colorScheme.primary
                              : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle, color: colorScheme.primary) : null,
                      onTap: () {
                        widget.onDateSelected(date);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.today),
                  label: Text(l10n.showCurrentMonth),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final currentMonth = DateTime(now.year, now.month);
                    widget.onDateSelected(currentMonth);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
