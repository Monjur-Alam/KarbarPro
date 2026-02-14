import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/constants/database_constants.dart';
import '../../data/report_repository.dart';
import '../../domain/due_ledger_model.dart';
import '../../services/report_generator.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../main.dart';

class DueLedgerScreen extends StatelessWidget {
  const DueLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('বাকি খাতা', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
        ),
        body: const DefaultTabController(
          length: 2,
          child: DueLedgerView(),
        ),
      ),
    );
  }
}

class DueLedgerView extends StatefulWidget {
  const DueLedgerView({super.key});

  @override
  State<DueLedgerView> createState() => _DueLedgerViewState();
}

class _DueLedgerViewState extends State<DueLedgerView> with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  List<CustomerDue> _allCustomers = [];
  List<CustomerDue> _filteredCustomers = []; // For current tab
  
  List<CustomerDue> _customersList = [];
  List<CustomerDue> _suppliersList = [];
  Map<String, dynamic> _summary = {
    'totalReceivable': 0.0,
    'totalCollected': 0.0,
    'totalPayable': 0.0,
    'totalPaid': 0.0,
  };
  bool _isLoading = true;
  
  // Filter & Sort States
  final TextEditingController _searchController = TextEditingController();
  String _selectedDateFilter = 'সব';
  String _sortBy = 'name_asc'; // name_asc, name_desc, balance_asc, balance_desc, last_transaction
  DateTime? _startDate;
  DateTime? _endDate;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _applyTabFilter();
      }
    });
    _loadData();
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
    // Refresh data when returning to this screen
    _loadData();
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

  void _applyDateFilter(String filter) async {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = now;

    if (filter == 'কাস্টম তারিখ') {
      final pickerDate = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: _startDate != null && _endDate != null 
            ? DateTimeRange(start: _startDate!, end: _endDate!) 
            : null,
      );
      if (pickerDate != null) {
        setState(() {
          _selectedDateFilter = 'কাস্টম (${DateFormat('dd/MM').format(pickerDate.start)} - ${DateFormat('dd/MM').format(pickerDate.end)})';
          _startDate = pickerDate.start;
          _endDate = pickerDate.end;
        });
        _loadData();
      }
      return;
    }

    switch (filter) {
      case 'আজ':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'গতকাল':
        start = DateTime(now.year, now.month, now.day - 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 1));
        break;
      case 'গত ৭ দিন':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'গত ৩০ দিন':
        start = now.subtract(const Duration(days: 30));
        break;
      case 'এই মাস':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'গত মাস':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'সব':
      default:
        start = null;
        end = null;
    }

    setState(() {
      _selectedDateFilter = filter;
      _startDate = start;
      _endDate = end;
    });
    _loadData();
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
    setState(() {
      _selectedDateFilter = 'সব';
      _startDate = null;
      _endDate = null;
    });
    _loadData();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'গ্রাহক (পাবো)'),
              Tab(text: 'সরবরাহকারী (দিবো)'),
            ],
            labelColor: Colors.teal.shade800,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal.shade800,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabView(isCustomer: true),
          _buildTabView(isCustomer: false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(isSupplier: _tabController.index == 1),
        backgroundColor: const Color(0xFF00695C),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text(_tabController.index == 0 ? 'নতুন গ্রাহক' : 'নতুন সরবরাহকারী', 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTabView({required bool isCustomer}) {
    final list = isCustomer ? _customersList : _suppliersList;
    // Apply search filter locally for the tab
    final search = _searchController.text.toLowerCase();
    final filteredList = list.where((c) => 
      c.name.toLowerCase().contains(search) || 
      (c.phone != null && c.phone!.contains(search))
    ).toList();

    return Column(
      children: [
        _buildTabSummaryCard(isCustomer: isCustomer),
        _buildFilterBar(),
        _buildActionBar(isCustomer: isCustomer, count: filteredList.length),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : filteredList.isEmpty
              ? _buildEmptyState()
              : _buildCustomerList(filteredList),
        ),
      ],
    );
  }

  Widget _buildTabSummaryCard({required bool isCustomer}) {
    final total = isCustomer ? (_summary['totalReceivable'] ?? 0.0) : (_summary['totalPayable'] ?? 0.0);
    final paid = isCustomer ? (_summary['totalCollected'] ?? 0.0) : (_summary['totalPaid'] ?? 0.0);
    final remaining = total - paid;
    
    final accentColor = isCustomer ? Colors.orange : Colors.blue.shade300;
    final labelTotal = isCustomer ? 'মোট পাবো' : 'মোট দিতে হবে';
    final labelPaid = isCustomer ? 'আদায় হয়েছে' : 'দিয়েছি';
    final labelRemaining = isCustomer ? 'বাকি আছে' : 'বাকি দিতে হবে';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF37474F), // Darker grey-blue for clean look
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(labelTotal, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('৳${_toBengaliDigits(total.toStringAsFixed(0))}', 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(labelPaid, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('৳${_toBengaliDigits(paid.toStringAsFixed(0))}', 
                    style: TextStyle(color: Colors.green.shade300, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(labelRemaining, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('৳${_toBengaliDigits(remaining.toStringAsFixed(0))}', 
                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalReceivable = _summary['totalReceivable'] ?? 0.0;
    final totalCollected = _summary['totalCollected'] ?? 0.0;
    final remainingReceivable = totalReceivable;

    final totalPayable = _summary['totalPayable'] ?? 0.0;
    final totalPaid = _summary['totalPaid'] ?? 0.0;
    final remainingPayable = totalPayable;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00695C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Left Side: Receivables
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('মোট পাবো (বাকি)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '৳${_toBengaliDigits(totalReceivable.toStringAsFixed(0))}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward, color: Colors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text('আদায়: ৳${_toBengaliDigits(totalCollected.toStringAsFixed(0))}', 
                            style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.white24),
                // Right Side: Payables
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('মোট দেবো (জমা)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          '৳${_toBengaliDigits(totalPayable.toStringAsFixed(0))}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.lightGreenAccent, size: 14),
                            const SizedBox(width: 4),
                            Text('দিয়েছি: ৳${_toBengaliDigits(totalPaid.toStringAsFixed(0))}', 
                              style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF004D40),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('বাকি আছে: ৳${_toBengaliDigits(remainingReceivable.toStringAsFixed(0))}', 
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text('বাকি দিতে হবে: ৳${_toBengaliDigits(remainingPayable.toStringAsFixed(0))}', 
                      style: const TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'গ্রাহক খুঁজুন...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _resetFilters)
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: _applyDateFilter,
            itemBuilder: (context) => ['সব', 'আজ', 'গতকাল', 'গত ৭ দিন', 'গত ৩০ দিন', 'এই মাস', 'গত মাস', 'কাস্টম তারিখ'].map((filter) => 
              PopupMenuItem(value: filter, child: Text(filter, style: const TextStyle(fontSize: 14)))
            ).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Text(_selectedDateFilter, style: const TextStyle(fontSize: 14, color: Colors.teal)),
                  const Icon(Icons.arrow_drop_down, color: Colors.teal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar({required bool isCustomer, required int count}) {
    final label = isCustomer ? 'গ্রাহক' : 'সরবরাহকারী';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label তালিকা (${_toBengaliDigits(count.toString())})', 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.blueGrey, size: 20),
            tooltip: 'সাজান',
            onSelected: (val) {
              setState(() => _sortBy = val);
              _sortCustomers();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name_asc', child: Text('নাম (A-Z)')),
              const PopupMenuItem(value: 'name_desc', child: Text('নাম (Z-A)')),
              const PopupMenuItem(value: 'balance_desc', child: Text('বাকি (বেশি থেকে কম)')),
              const PopupMenuItem(value: 'balance_asc', child: Text('বাকি (কম থেকে বেশি)')),
              const PopupMenuItem(value: 'last_transaction', child: Text('সর্বশেষ লেনদেন')),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _generateAndSharePDF(isCustomer: isCustomer),
            icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.teal),
            label: Text('$label PDF', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.teal.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(List<CustomerDue> customers) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _buildCustomerDueCard(customer);
      },
    );
  }

  Widget _buildCustomerDueCard(CustomerDue customer) {
    return Dismissible(
      key: Key('customer_${customer.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (customer.currentCreditBalance > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('বাকি পরিশোধ না করে গ্রাহক মুছা যাবে না'), backgroundColor: Colors.red),
          );
          return false;
        }
        return await _showDeleteConfirmation(customer);
      },
      onDismissed: (direction) => _deleteCustomer(customer.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white),
            Text('মুছুন', style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
        elevation: 0,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(customer.name.isNotEmpty ? customer.name[0] : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.phone ?? 'ফোন নম্বর নেই', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              if (customer.lastTransactionDate != null)
                Text('শেয লেনদেন: ${DateFormat('dd MMM').format(customer.lastTransactionDate!)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '৳${_toBengaliDigits(customer.currentCreditBalance.abs().toStringAsFixed(0))}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: customer.type == 'customer' ? Colors.red : Colors.green),
              ),
              Text(customer.type == 'customer' ? 'মোট বাকি' : 'বাকি দিতে হবে', 
                style: TextStyle(fontSize: 10, color: customer.type == 'customer' ? Colors.red : Colors.green)),
            ],
          ),
          onTap: () => _showCustomerMenu(context, customer),
        ),
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
      shopName: 'আমার দোকান', // In real app, get from settings
      summary: _summary,
      customers: _filteredCustomers,
      transactionHistories: histories,
    );
  }

  Future<void> _deleteCustomer(int id) async {
    final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
    await repo.deleteCustomer(id);
    _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('গ্রাহক মুছে ফেলা হয়েছে')));
  }

  Future<bool?> _showDeleteConfirmation(CustomerDue customer) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ সতর্কতা'),
        content: Text('আপনি কি এই গ্রাহককে মুছে ফেলতে চান?\n\nনাম: ${customer.name}\nবাকি: ৳${_toBengaliDigits(customer.currentCreditBalance.toStringAsFixed(0))}\n\nসকল লেনদেন ইতিহাস মুছে যাবে!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.red))),
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
            leading: const Icon(Icons.edit_outlined, color: Colors.blue),
            title: const Text('গ্রাহক তথ্য পরিবর্তন করুন'),
            onTap: () {
              Navigator.pop(context);
              _showEditCustomerDialog(customer);
            },
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined, color: Colors.green),
            title: const Text('বকেয়া পরিশোধের হিসাব রাখুন'),
            subtitle: const Text('কাস্টমারের কাছ থেকে টাকা জমা নিন'),
            onTap: () {
              Navigator.pop(context);
              _showPaymentCollectionDialog(context, customer);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blue),
            title: const Text('বাকি লেনদেনের ইতিহাস'),
            onTap: () {
              Navigator.pop(context);
              _showTransactionHistorySheet(context, customer);
            },
          ),
          ListTile(
            leading: const Icon(Icons.call_outlined, color: Colors.orange),
            title: const Text('যোগাযোগ করুন'),
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
        title: const Text('গ্রাহক সম্পাদনা'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'নাম (আবশ্যক)')),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর (আবশ্যক)')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'ঠিকানা (ঐচ্ছিক)')),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: 'মন্তব্য (ঐচ্ছিক)')),
              const SizedBox(height: 16),
              Text('বর্তমান বাকি: ৳${_toBengaliDigits(customer.currentCreditBalance.toStringAsFixed(0))}', 
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('নাম এবং ফোন নম্বর প্রয়োজন')));
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('গ্রাহক তথ্য আপডেট হয়েছে')));
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade200),
          const SizedBox(height: 16),
          const Text('কোনো গ্রাহক পাওয়া যায়নি', style: TextStyle(color: Colors.grey)),
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isSupplier ? 'নতুন সরবরাহকারী' : 'নতুন গ্রাহক'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: customerType,
                  decoration: const InputDecoration(labelText: 'ধরণ'),
                  items: const [
                    DropdownMenuItem(value: 'customer', child: Text('গ্রাহক (আমি পাবো)')),
                    DropdownMenuItem(value: 'supplier', child: Text('সাপ্লায়ার (আমি দিবো)')),
                  ],
                  onChanged: (val) => setState(() => customerType = val!),
                ),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'নাম (আবশ্যক)')),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর (আবশ্যক)')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'ঠিকানা (ঐচ্ছিক)')),
                TextField(controller: notesController, decoration: const InputDecoration(labelText: 'মন্তব্য (ঐচ্ছিক)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('নাম এবং ফোন নম্বর প্রয়োজন')));
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('গ্রাহক যুক্ত হয়েছে')));
              },
              child: const Text('সংরক্ষণ করুন'),
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
        title: const Text('টাকা জমা নিন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('কাস্টমার: ${customer.name}'),
            const SizedBox(height: 8),
            Text('বর্তমান বাকি: ৳${_toBengaliDigits(customer.currentCreditBalance.toStringAsFixed(0))}', 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'জমা করা টাকার পরিমাণ', prefixText: '৳', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)', border: OutlineInputBorder()),
            ),
          ],
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
              
              final repo = ReportRepository(dbHelper: context.read<DatabaseHelper>());
              await repo.recordCustomerPayment(
                customerId: customer.id,
                amount: amount,
                notes: notesController.text,
              );

              if (!mounted) return;
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('টাকা জমা নেওয়া সফল হয়েছে')));
            },
            child: const Text('নিশ্চিত করুন'),
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
                  child: Text('লেনদেনের ইতিহাস - ${customer.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Divider(),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('কোনো লেনদেনের ইতিহাস নেই'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: history.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final trans = history[index];
                            final isSale = trans.transactionType == 'sale';
                            return ListTile(
                              title: Text(isSale ? 'পণ্য ক্রয় (বাকি)' : 'টাকা পরিশোধ'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (trans.description != null) Text(trans.description!, style: const TextStyle(fontSize: 12)),
                                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(trans.transactionDate), 
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isSale ? "+" : "-"} ৳${_toBengaliDigits(trans.amount.toStringAsFixed(0))}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isSale ? Colors.red : Colors.green),
                                  ),
                                  Text('ব্যালেন্স: ৳${_toBengaliDigits(trans.balanceAfter.toStringAsFixed(0))}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
            leading: const Icon(Icons.call, color: Colors.green),
            title: const Text('কল করুন'),
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
            leading: const Icon(Icons.message, color: Colors.blue),
            title: const Text('এসএমএস পাঠান'),
            onTap: () async {
              final url = 'sms:${customer.phone}?body=আপনার দোকানের বাকি ৳${customer.currentCreditBalance} পরিশোধ করার জন্য অনুরোধ করা হলো।';
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
