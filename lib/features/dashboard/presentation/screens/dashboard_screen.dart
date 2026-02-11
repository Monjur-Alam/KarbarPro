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
import 'package:amar_dokan/features/auth/presentation/screens/profile_screen.dart';
import '../../../reports/presentation/screens/due_ledger_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  void setIndex(int index) {
    setState(() => _selectedIndex = index);
  }
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
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


  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const DashboardHome(),
      const InventoryView(),
      const SalesView(),
      const SalesReportView(),
      const ProfileScreen(),
    ];

    final List<String> titles = [
      'আমার দোকান',
      'স্টক বা ইনভেন্টরি',
      'পণ্য বিক্রয়',
      'বিক্রির রিপোর্ট',
      'প্রোফাইল',
    ];

    return Scaffold(
      appBar: _buildAppBar(titles[_selectedIndex]),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      actions: [
        BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            SyncStatus syncStatus = SyncStatus.idle;
            if (state is HomeLoaded) {
              syncStatus = state.syncStatus;
            }
            return _buildSyncIndicator(syncStatus);
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSyncIndicator(SyncStatus status) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.orange;
        label = 'সিঙ্ক হচ্ছে...';
        break;
      case SyncStatus.success:
        icon = Icons.cloud_done;
        color = Colors.green;
        label = 'অনলাইন';
        break;
      case SyncStatus.failed:
        icon = Icons.sync_problem;
        color = Colors.red;
        label = 'ব্যর্থ';
        break;
      case SyncStatus.queued:
      case SyncStatus.paused:
        icon = Icons.cloud_off;
        color = Colors.grey;
        label = 'অফলাইন';
        break;
      case SyncStatus.idle:
        icon = Icons.cloud_queue;
        color = Colors.blueGrey;
        label = 'ব্যবহার্য';
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
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'হোম'),
        NavigationDestination(icon: Icon(Icons.list_alt), label: 'তালিকা'),
        NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'বিক্রয়'),
        NavigationDestination(icon: Icon(Icons.bar_chart), label: 'রিপোর্ট'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'প্রোফাইল'),
      ],
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickAction(this.label, this.icon, this.color, this.onTap);
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  String _toBengaliDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < english.length; i++) {
        input = input.replaceAll(english[i], bengali[i]);
    }
    return input;
  }

  String _formatCurrency(double amount) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String input = amount.toStringAsFixed(0);
    for (int i = 0; i < english.length; i++) {
        input = input.replaceAll(english[i], bengali[i]);
    }
    return input;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<HomeBloc>().add(LoadDashboard());
      },
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HomeLoaded) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSummaryCard(state),
                   const SizedBox(height: 24),
                   _buildSectionTitle('কুইক অ্যাকশন'),
                   const SizedBox(height: 12),
                   _buildQuickActionsGrid(context),
                   const SizedBox(height: 24),
                   if (state.summary.lowStockProducts.isNotEmpty) ...[
                     _buildSectionTitle('সতর্কতা (স্টক কম)'),
                     const SizedBox(height: 12),
                     _buildAlertsSection(state.summary.lowStockProducts),
                     const SizedBox(height: 24),
                   ],
                   _buildSectionTitle('সাম্প্রতিক বিক্রি'),
                   const SizedBox(height: 12),
                   _buildRecentActivityList(state.summary.recentSales),
                ],
              ),
            );
          } else if (state is HomeError) {
            return Center(child: Text('ত্রুটি: ${state.message}'));
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildSummaryCard(HomeLoaded state) {
    final today = _toBengaliDigits(DateFormat('d MMMM, yyyy', 'bn_BD').format(DateTime.now()));
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(today, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Badge(label: Text('লাইভ'), backgroundColor: Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('মোট বিক্রি (আজ)', _toBengaliDigits(state.summary.totalSalesToday.toString())),
              _buildSummaryItem('মোট টাকা (আজ)', '৳${_formatCurrency(state.summary.totalAmountToday)}'),
              _buildSummaryItem('লাভ (আজ)', '৳${_formatCurrency(state.summary.totalProfitToday)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
     final actions = [
      _QuickAction('পণ্য বিক্রয়', Icons.shopping_cart, Colors.blue, () {
        final state = context.findAncestorStateOfType<DashboardScreenState>();
        state?.setIndex(2);
      }),
      _QuickAction('পণ্যের তালিকা', Icons.inventory, Colors.purple, () {
        final state = context.findAncestorStateOfType<DashboardScreenState>();
        state?.setIndex(1);
      }),
      _QuickAction('আজকের বিক্রি', Icons.receipt_long, Colors.green, () {
        final state = context.findAncestorStateOfType<DashboardScreenState>();
        state?.setIndex(3);
      }),
      _QuickAction('বিক্রির রিপোর্ট', Icons.bar_chart, Colors.orange, () {
        final state = context.findAncestorStateOfType<DashboardScreenState>();
        state?.setIndex(3);
      }),
      _QuickAction('দোকানের খরচ', Icons.account_balance_wallet, Colors.red, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseScreen()));
      }),
      _QuickAction('বাকি খাতা', Icons.menu_book, Colors.purple, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => DueLedgerScreen()));
      }),
      _QuickAction('সিঙ্ক ড্রাইভ', Icons.cloud_sync, Colors.teal, () {
        context.read<SyncService>().performSync(isManual: true);
      }),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, color: action.color, size: 30),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsSection(List<Map<String, dynamic>> lowStock) {
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
                      Text('স্টক: ${_toBengaliDigits(p['current_stock'].toString())}', style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
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

  Widget _buildRecentActivityList(List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return const Center(child: Text('কোন সাম্প্রতিক বিক্রি নেই'));
    }
    return Column(
      children: sales.map((sale) {
        final date = DateTime.parse(sale['sale_date']);
        final timeStr = _toBengaliDigits(DateFormat('hh:mm a').format(date));
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.receipt, color: Colors.blue),
            ),
            title: Text('ইনভয়েস: ${_toBengaliDigits(sale['invoice_number'])}'),
            subtitle: Text(timeStr),
            trailing: Text(
              '৳${_formatCurrency(sale['total_amount'])}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      }).toList(),
    );
  }
}
