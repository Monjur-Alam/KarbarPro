import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../bloc/report_bloc.dart';
import '../../domain/report_models.dart';
import '../../../sales/domain/sale.dart';
import '../../../../core/database/database_helper.dart';
import '../../data/report_repository.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../sales/presentation/screens/sale_detail_screen.dart';
import '../../../sales/data/sales_repository.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##,###');
    return '৳${_toBengaliDigits(formatter.format(amount))}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportBloc(
        repository: ReportRepository(dbHelper: context.read<DatabaseHelper>()),
      )..add(LoadReports(startDate: _startDate, endDate: _endDate)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('বিক্রির রিপোর্ট', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            BlocBuilder<ReportBloc, ReportState>(
              builder: (context, state) {
                return IconButton(
                  icon: const Icon(Icons.download_outlined), 
                  onPressed: state is ReportLoaded ? () => _showExportDialog(context, state) : null,
                  tooltip: 'এক্সপোর্ট',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh), 
              onPressed: () {
                context.read<ReportBloc>().add(RefreshReports());
              },
              tooltip: 'রিফ্রেশ',
            ),
          ],
        ),
        body: BlocBuilder<ReportBloc, ReportState>(
          builder: (context, state) {
            if (state is ReportLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ReportLoaded) {
              return _buildReportContent(context, state);
            } else if (state is ReportError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportLoaded state) {
    return RefreshIndicator(
      onRefresh: () async => context.read<ReportBloc>().add(RefreshReports()),
      child: Column(
        children: [
          _buildDateFilterRow(context, state),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSummarySection(state.reportData.stats),
                   const SizedBox(height: 24),
                   _buildChartsSection(state.reportData),
                   const SizedBox(height: 24),
                   _buildQuickReportsSection(context, state),
                   const SizedBox(height: 24),
                   _buildPaymentDistribution(state.reportData.paymentSummary),
                   const SizedBox(height: 24),
                   _buildTopProductsSection(state.reportData.topProducts),
                   const SizedBox(height: 24),
                   _buildSalesListHeader(state.sales.length),
                   const SizedBox(height: 12),
                   _buildSalesTabs(context, state),
                   const SizedBox(height: 80), // Space for bottom actions
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterRow(BuildContext context, ReportLoaded state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showDateRangePicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('dd MMM').format(state.startDate)} - ${DateFormat('dd MMM').format(state.endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildQuickFilter(context, 'আজ', () {
             final today = DateTime.now();
             context.read<ReportBloc>().add(LoadReports(startDate: today, endDate: today));
          }),
        ],
      ),
    );
  }

  Widget _buildQuickFilter(BuildContext context, String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSummarySection(SummaryStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('বিক্রি', _toBengaliDigits(stats.salesCount.toString()), Icons.receipt_long, Colors.blue),
        _buildStatCard('মোট আয়', _formatCurrency(stats.totalRevenue), Icons.payments, Colors.green, growth: stats.revenueGrowth),
        _buildStatCard('মোট লাভ', _formatCurrency(stats.totalProfit), Icons.trending_up, Colors.orange, subLabel: 'মার্জিন ${_toBengaliDigits(stats.profitMargin.toStringAsFixed(1))}%'),
        _buildStatCard('গড় বিক্রয়', _formatCurrency(stats.averageSale), Icons.bar_chart, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {double? growth, String? subLabel}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (growth != null)
                 Row(
                   children: [
                     Icon(growth >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: growth >= 0 ? Colors.green : Colors.red, size: 20),
                     Text('${_toBengaliDigits(growth.abs().toStringAsFixed(1))}%', style: TextStyle(color: growth >= 0 ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                   ],
                 )
              else if (subLabel != null)
                 Text(subLabel, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReportsSection(BuildContext context, ReportLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('কুইক রিপোর্ট', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildQuickReportCard(
                'পণ্য রিপোর্ট', 
                Icons.inventory_2_outlined, 
                Colors.blue, 
                () => ReportExportService.exportProductReport(state.reportData.topProducts, state.startDate, state.endDate)
              ),
              _buildQuickReportCard(
                'স্টক রিপোর্ট', 
                Icons.warning_amber_rounded, 
                Colors.orange, 
                () async {
                  final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
                  final products = await repo.getLowStockProducts();
                  ReportExportService.exportStockReport(products);
                }
              ),
              _buildQuickReportCard(
                'কাস্টমার রিপোর্ট', 
                Icons.people_outline, 
                Colors.purple, 
                () {}
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickReportCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(SalesReportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('বিক্রয়ের প্রবণতা (টাকা)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          height: 220,
          padding: const EdgeInsets.only(top: 24, right: 24, left: 12, bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: LineChart(
             LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(_toBengaliDigits(value.toInt().toString()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < data.dailyTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('dd/MM').format(data.dailyTrend[value.toInt()].date),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.dailyTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList(),
                    isCurved: true,
                    color: Colors.blue.shade700,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true, 
                      gradient: LinearGradient(
                        colors: [Colors.blue.withValues(alpha: 0.2), Colors.blue.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: data.dailyTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.profit)).toList(),
                    isCurved: true,
                    color: Colors.orange.shade700,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
             ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDistribution(List<PaymentTypeSummary> summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('পরিশোধের ধরণ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: summary.map((s) {
                      final color = s.paymentType == 'cash' ? Colors.green : Colors.red;
                      return PieChartSectionData(
                        color: color,
                        value: s.revenue,
                        title: '',
                        radius: 20,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: summary.map((s) {
                    final color = s.paymentType == 'cash' ? Colors.green : Colors.red;
                    final label = s.paymentType == 'cash' ? 'নগদ' : 'বাকি';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
                          Text(_formatCurrency(s.revenue), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductsSection(List<ProductReportItem> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('বেশি বিক্রিত পণ্য', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
           decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = products[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  radius: 12,
                  child: Text(_toBengaliDigits((index + 1).toString()), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                title: Text(item.productName, style: const TextStyle(fontSize: 14)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_toBengaliDigits(item.quantitySold.toString())} টি', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatCurrency(item.totalRevenue), style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalesListHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('বিক্রির তালিকা (${_toBengaliDigits(count.toString())})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.filter_list), 
          onPressed: () => _showFilterBottomSheet(context),
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('অ্যাডভান্সড ফিল্টার', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildFilterField('সার্চ (ক্রেতা, ইনভয়েস)', Icons.search),
            const SizedBox(height: 12),
            _buildFilterField('মিনিমাম টাকা', Icons.money),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('প্রয়োগ করুন'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterField(String hint, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildSalesTabs(BuildContext context, ReportLoaded state) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,
          onTap: (index) {
             String type = 'all';
             if (index == 1) type = 'cash';
             if (index == 2) type = 'credit';
             context.read<ReportBloc>().add(LoadReports(startDate: state.startDate, endDate: state.endDate, paymentType: type));
          },
          tabs: const [
            Tab(text: 'সব'),
            Tab(text: 'নগদ'),
            Tab(text: 'বাকি'),
          ],
        ),
        const SizedBox(height: 16),
        _buildSalesList(state.sales),
      ],
    );
  }

  Widget _buildSalesList(List<Sale> sales) {
    if (sales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('এই সময়ে কোনো বিক্রয় নেই', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
           margin: const EdgeInsets.only(bottom: 12),
           elevation: 0,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
           child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.receipt, color: Colors.blue, size: 20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ইনভয়েস #${_toBengaliDigits(sale.invoiceId)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(_formatCurrency(sale.totalAmount), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        _toBengaliDigits(DateFormat('dd MMM • hh:mm a').format(sale.saleDate)),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sale.paymentMethod == 'cash' ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sale.paymentMethod == 'cash' ? 'নগদ' : 'বাকি',
                          style: TextStyle(color: sale.paymentMethod == 'cash' ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (sale.customerName != null) 
                    Text(sale.customerName!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
              ),
              onTap: () => _navigateToSaleDetail(sale),
           ),
        );
      },
    );
  }

  void _navigateToSaleDetail(Sale sale) async {
    final salesRepo = SalesRepository(dbHelper: context.read<DatabaseHelper>());
    final fullSale = await salesRepo.getSaleById(sale.id!);
    if (fullSale != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => SaleDetailScreen(sale: fullSale)));
    }
  }

  void _showExportDialog(BuildContext context, ReportState state) {
    if (state is! ReportLoaded) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('রিপোর্ট এক্সপোর্ট করুন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('PDF হিসেবে সেভ করুন'),
            onTap: () {
              Navigator.pop(context);
              ReportExportService.exportToPdf(state.reportData, state.sales, state.startDate, state.endDate);
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.green),
            title: const Text('Excel হিসেবে সেভ করুন'),
            onTap: () {
              Navigator.pop(context);
              ReportExportService.exportToExcel(state.reportData, state.sales, state.startDate, state.endDate);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      if (!mounted) return;
      context.read<ReportBloc>().add(LoadReports(startDate: picked.start, endDate: picked.end));
    }
  }
}
