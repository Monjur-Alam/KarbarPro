import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:amar_dokan/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:amar_dokan/features/customers/presentation/bloc/customer_bloc.dart';
import 'package:amar_dokan/features/customers/domain/customer.dart';
import 'package:amar_dokan/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:amar_dokan/features/inventory/domain/product.dart';
import 'package:amar_dokan/features/sales/domain/sale.dart';
import 'package:amar_dokan/core/services/invoice_service.dart';
import 'package:amar_dokan/features/reports/presentation/bloc/report_bloc.dart';
import 'package:amar_dokan/features/reports/services/report_generator.dart';
import 'package:amar_dokan/features/dashboard/presentation/bloc/home_bloc.dart';
import 'package:amar_dokan/core/services/connectivity_service.dart';
import '../widgets/sale_form_bottom_sheet.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/database_constants.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SalesView();
  }
}

class SalesView extends StatefulWidget {
  const SalesView({super.key});

  @override
  State<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<SalesView> {
  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(LoadSalesInitialData());
  }

  @override
  void dispose() {
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
          
          // Refresh other Blocs for real-time update
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('বিক্রয় তথ্য ও ইতিহাস', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (state is SalesDataLoaded)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () {
                     String shopName = 'আমার দোকান';
                     // In real app, get from settings

                     ReportGenerator.generateSalesPDF(
                       shopName: shopName,
                       sales: state.salesHistory,
                       summary: state.statistics['thisMonth'] ?? {'total': 0.0, 'cash': 0.0, 'credit': 0.0},
                     );
                  },
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showSaleFormBottomSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('নতুন বিক্রয়'),
          ),
          body: _buildBody(state),
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
               child: const Text('পুনরায় চেষ্টা করুন'),
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
            _buildBalanceCard(state),
            _buildHistoryTabs(state),
            _buildFilterBar(state),
            Expanded(
              child: TabBarView(
                children: [
                  _buildHistoryList(state, 'all'),
                  _buildHistoryList(state, 'cash'),
                  _buildHistoryList(state, 'credit'),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return const Center(child: Text('বিক্রয় ডাটা লোড করা যাচ্ছে না'));
  }

  Widget _buildBalanceCard(SalesDataLoaded state) {
    final stats = state.statistics;
    final today = stats['today'] ?? {'total': 0.0, 'cash': 0.0, 'credit': 0.0};
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('আজকের মোট বিক্রি', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  SizedBox(height: 4),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('${_toBengaliDigits('12')}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          Center(
            child: Text(
              '৳${_toBengaliDigits(NumberFormat('#,##,###').format(today['total']))}',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildBalanceStatItem('নগদ আদায়', today['cash'], Colors.green.shade300),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildBalanceStatItem('বাকি বিক্রি', today['credit'], Colors.orange.shade300),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStatItem(String label, dynamic value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '৳${_toBengaliDigits(NumberFormat('#,##,###').format(value))}',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTabs(SalesDataLoaded state) {
    return TabBar(
      onTap: (index) {
        String tab = 'all';
        if (index == 1) tab = 'cash';
        if (index == 2) tab = 'credit';
        context.read<SalesBloc>().add(ChangeSalesTab(tab));
      },
      tabs: const [
        Tab(text: 'সব'),
        Tab(text: 'নগদ'),
        Tab(text: 'বাকি'),
      ],
      labelColor: Colors.blue,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Colors.blue,
      indicatorWeight: 3,
    );
  }

  Widget _buildFilterBar(SalesDataLoaded state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => context.read<SalesBloc>().add(UpdateSalesFilters(searchQuery: v)),
              decoration: InputDecoration(
                hintText: 'ইনভয়েস বা গ্রাহক খুঁজুন...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildFilterButton(Icons.calendar_today, () => _showDateRangePicker(context, state)),
          const SizedBox(width: 8),
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

  Widget _buildHistoryList(SalesDataLoaded state, String type) {
    final sales = state.salesHistory;
    
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('কোনো বিক্রয় তথ্য পাওয়া যায়নি', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: InkWell(
            onTap: () {
               // Show details
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: sale.paymentMethod == 'cash' ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      sale.paymentMethod == 'cash' ? Icons.payments : Icons.history_toggle_off,
                      color: sale.paymentMethod == 'cash' ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.customerName ?? 'সাধারণ গ্রাহক',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'আইডি: ${_toBengaliDigits(sale.invoiceId)}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Colors.grey)),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(sale.saleDate),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '৳${_toBengaliDigits(NumberFormat('#,##,###').format(sale.totalAmount))}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        sale.paymentMethod == 'cash' ? 'নগদ' : 'বাকি',
                        style: TextStyle(
                          color: sale.paymentMethod == 'cash' ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDateRangePicker(BuildContext context, SalesDataLoaded state) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: state.startDate != null && state.endDate != null 
          ? DateTimeRange(start: state.startDate!, end: state.endDate!) 
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      if (!context.mounted) return;
      context.read<SalesBloc>().add(UpdateSalesFilters(startDate: picked.start, endDate: picked.end));
    }
  }

  void _showSortOptions(BuildContext context, SalesDataLoaded state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('সাজানোর অপশন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          _buildSortItem(context, 'সবচেয়ে নতুন', 'date_desc', state.sortBy == 'date_desc'),
          _buildSortItem(context, 'সবচেয়ে পুরাতন', 'date_asc', state.sortBy == 'date_asc'),
          _buildSortItem(context, 'বেশি টাকা', 'amount_desc', state.sortBy == 'amount_desc'),
          _buildSortItem(context, 'কম টাকা', 'amount_asc', state.sortBy == 'amount_asc'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSortItem(BuildContext context, String title, String value, bool isSelected) {
    return ListTile(
      title: Text(title),
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
        title: const Center(child: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text('বিক্রয় সফল হয়েছে!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDataRow('ইনভয়েস:', _toBengaliDigits(sale.invoiceId)),
            _buildDataRow('মোট পরিমাণ:', '৳${_toBengaliDigits(sale.totalAmount.toStringAsFixed(0))}'),
            _buildDataRow('পেমেন্ট:', sale.paymentMethod == 'cash' ? 'নগদ' : 'বাকি'),
            const Divider(),
            const SizedBox(height: 10),
            _buildActionTile(Icons.print, 'প্রিন্ট রসিদ', Colors.blue, () => InvoiceService.printReceipt(sale)),
            _buildActionTile(Icons.share, 'রসিদ শেয়ার করুন', Colors.green, () => InvoiceService.shareReceipt(sale)),
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
