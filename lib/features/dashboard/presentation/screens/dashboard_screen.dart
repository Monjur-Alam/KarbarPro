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




  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const DashboardHome(),
      const SalesView(),
      const DueLedgerView(),
      const InventoryScreen(),
      const ExpenseView(),
    ];

    final List<String> titles = [
      'আমার দোকান',
      'পণ্য বিক্রয়',
      'বাকি খাতা',
      'পণ্যের তালিকা',
      'দোকানের খরচ',
    ];
    return Scaffold(
      appBar: _buildAppBar(titles[_selectedIndex], context),
      endDrawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(String title, BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      centerTitle: false,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 18, color: Colors.black),
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
        // IconButton(
        //   icon: const Icon(Icons.notifications_none, color: Colors.black,),
        //   onPressed: () {},
        // ),
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black,),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
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
        NavigationDestination(
          icon: Icon(Icons.home_outlined), 
          selectedIcon: Icon(Icons.home),
          label: 'হোম'
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined), 
          selectedIcon: Icon(Icons.shopping_cart),
          label: 'বিক্রয়'
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined), 
          selectedIcon: Icon(Icons.menu_book),
          label: 'বাকি খাতা'
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined), 
          selectedIcon: Icon(Icons.inventory_2),
          label: 'তালিকা'
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined), 
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'খরচ'
        ),
      ],
    );
  }
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
                   const SizedBox(height: 16),
                   _buildBakirKhataSummaryCard(context, state),
                   const SizedBox(height: 24),
                   _buildReportOptions(context),
                   const SizedBox(height: 24),
                   _buildSectionTitle('সাম্প্রতিক বিক্রি'),
                   const SizedBox(height: 12),
                   _buildRecentActivityList(state.summary.recentSales),
                   const SizedBox(height: 24),
                   if (state.summary.lowStockProducts.isNotEmpty) ...[
                     _buildSectionTitle('সতর্কতা (স্টক কম)'),
                     const SizedBox(height: 12),
                     _buildAlertsSection(state.summary.lowStockProducts),
                     const SizedBox(height: 24),
                   ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('দোকানের মেইন ব্যালেন্স', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('৳${_formatCurrency(state.summary.mainBalance)}', 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
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

  Widget _buildReportOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('রিপোর্ট'),
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
              label: 'বিক্রয় রিপোর্ট',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen())),
            ),
            _buildReportCard(
              context,
              icon: Icons.account_balance_wallet,
              label: 'খরচ রিপোর্ট',
              color: Colors.orange,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<DashboardScreenState>();
                dashboardState?.setIndex(4);
              },
            ),
            _buildReportCard(
              context,
              icon: Icons.inventory_2,
              label: 'স্টক রিপোর্ট',
              color: Colors.green,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<DashboardScreenState>();
                dashboardState?.setIndex(3);
              },
            ),
            _buildReportCard(
              context,
              icon: Icons.people,
              label: 'বাকি খাতা রিপোর্ট',
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

  Widget _buildBakirKhataSummaryCard(BuildContext context, HomeLoaded state) {
    return InkWell(
      onTap: () {
        final dashboardState = context.findAncestorStateOfType<DashboardScreenState>();
        dashboardState?.setState(() => dashboardState._selectedIndex = 2);
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('বাকির খাতা সারসংক্ষেপ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   TextButton.icon(
                     onPressed: () {
                        final dashboardState = context.findAncestorStateOfType<DashboardScreenState>();
                        dashboardState?.setState(() => dashboardState._selectedIndex = 2);
                     },
                     icon: const Icon(Icons.visibility, size: 16, color: Colors.blue),
                     label: const Text('বিস্তারিত', style: TextStyle(color: Colors.blue, fontSize: 13)),
                     style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                   ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // আমি পাবো (Receivables)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('আমি পাবো', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        _buildBakirMiniRow('মোট বাকি:', '৳${_formatCurrency(state.summary.totalReceivable)}'),
                        _buildBakirMiniRow('আদায়:', '৳${_formatCurrency(state.summary.totalCollected)}'),
                        const Divider(height: 16),
                        _buildBakirMiniRow('বাকি আছে:', '৳${_formatCurrency(state.summary.totalReceivable - state.summary.totalCollected)}', 
                          valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                  ),
                  Container(height: 80, width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 16)),
                  // আমি দিবো (Payables)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('আমি দিবো', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        _buildBakirMiniRow('মোট বাকি:', '৳${_formatCurrency(state.summary.totalPayable)}'),
                        _buildBakirMiniRow('দিয়েছি:', '৳${_formatCurrency(state.summary.totalPaid)}'),
                        const Divider(height: 16),
                        _buildBakirMiniRow('বাকি দিতে হবে:', '৳${_formatCurrency(state.summary.totalPayable - state.summary.totalPaid)}', 
                          valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBakirMiniRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: valueStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
