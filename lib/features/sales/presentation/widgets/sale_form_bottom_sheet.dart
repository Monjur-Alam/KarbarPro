import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../customers/domain/customer.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../inventory/domain/product.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../bloc/sales_bloc.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';

class SaleFormBottomSheet extends StatefulWidget {
  const SaleFormBottomSheet({super.key});

  @override
  State<SaleFormBottomSheet> createState() => _SaleFormBottomSheetState();
}

class _SaleFormBottomSheetState extends State<SaleFormBottomSheet> {
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  Product? _selectedProduct;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
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

  void _onProductSelected(Product product) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedProduct = product;
      _priceController.text = product.sellingPrice.toStringAsFixed(0);
      _quantityController.text = '1';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          Navigator.pop(context); // Close on success
        }
      },
      builder: (context, state) {
        if (state is! SalesDataLoaded) return const Center(child: CircularProgressIndicator());

        double total = 0;
        if (_selectedProduct != null) {
          double qty = double.tryParse(_quantityController.text) ?? 0;
          double price = double.tryParse(_priceController.text) ?? 0;
          total = qty * price;
        }

        double discount = double.tryParse(_discountController.text) ?? 0;
        double finalTotal = total - discount;
        if (finalTotal < 0) finalTotal = 0;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 12),
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('পণ্য বিক্রয় করুন', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Product Selection
                  _buildSectionTitle('পণ্য নির্বাচন করুন *'),
                  const SizedBox(height: 8),
                  _buildProductSelector(),
                  
                  if (_selectedProduct != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_quantityController, 'পরিমাণ *', suffix: _selectedProduct!.unit, isNumber: true, onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_priceController, 'মূল্য (প্রতি একক) *', prefix: '৳', isNumber: true, onChanged: (_) => setState(() {}))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('মোট মূল্য', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('৳${_toBengaliDigits(total.toStringAsFixed(0))}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _buildSectionTitle('পেমেন্ট ধরন *'),
                  const SizedBox(height: 8),
                  _buildPaymentTypeToggle(state),

                  if (state.paymentType == PaymentType.credit) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('গ্রাহক নির্বাচন করুন *'),
                    const SizedBox(height: 8),
                    _buildCustomerSelector(state.selectedCustomer),
                  ],

                  const SizedBox(height: 16),
                  _buildTextField(_notesController, 'বিবরণ/মন্তব্য (ঐচ্ছিক)', maxLines: 2),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('বাতিল করুন'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _validateAndSubmit(state, finalTotal),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: state.isSubmitting 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('বিক্রয় সম্পন্ন করুন (৳${_toBengaliDigits(finalTotal.toStringAsFixed(0))})'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey));
  }

  Widget _buildTextField(TextEditingController controller, String label, {String? prefix, String? suffix, bool isNumber = false, int maxLines = 1, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildProductSelector() {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        List<Product> products = [];
        if (state is InventoryLoaded) products = state.products.where((p) => p.currentStock > 0).toList();

        return InkWell(
          onTap: () => _showSearchablePicker<Product>(
            title: 'পণ্য নির্বাচন করুন',
            items: products,
            itemLabel: (p) => p.name,
            itemSublabel: (p) => 'স্টক: ${_toBengaliDigits(p.currentStock.toString())} ${p.unit}',
            onSelected: _onProductSelected,
            hintText: 'পণ্য খুঁজুন...',
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(child: Text(_selectedProduct?.name ?? 'পণ্য নির্বাচন করুন...', style: TextStyle(color: _selectedProduct != null ? Colors.black : Colors.grey.shade600))),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentTypeToggle(SalesDataLoaded state) {
    return Row(
      children: [
        _buildToggleItem('নগদ (Cash)', PaymentType.cash, state.paymentType == PaymentType.cash, Colors.green),
        const SizedBox(width: 12),
        _buildToggleItem('বাকি (Credit)', PaymentType.credit, state.paymentType == PaymentType.credit, Colors.orange),
      ],
    );
  }

  Widget _buildToggleItem(String label, PaymentType type, bool isSelected, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () => context.read<SalesBloc>().add(TogglePaymentType(type)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(label, style: TextStyle(color: isSelected ? color : Colors.grey.shade600, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildCustomerSelector(Customer? selectedCustomer) {
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        List<Customer> customers = [];
        if (state is CustomerLoaded) customers = state.customers;

        return Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showSearchablePicker<Customer>(
                  title: 'গ্রাহক নির্বাচন করুন',
                  items: customers,
                  itemLabel: (c) => c.name,
                  itemSublabel: (c) => c.phone,
                  onSelected: (c) => context.read<SalesBloc>().add(SelectCustomer(c)),
                  hintText: 'গ্রাহক খুঁজুন...',
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(child: Text(selectedCustomer?.name ?? 'গ্রাহক নির্বাচন করুন...', style: TextStyle(color: selectedCustomer != null ? Colors.black : Colors.grey.shade600))),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showAddCustomerDialog(context),
              icon: const Icon(Icons.person_add_alt_1, color: Colors.blue),
              style: IconButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        );
      },
    );
  }

  VoidCallback? _validateAndSubmit(SalesDataLoaded state, double finalTotal) {
    if (_selectedProduct == null) return null;
    double qty = double.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0 || qty > _selectedProduct!.currentStock) return null;
    if (state.paymentType == PaymentType.credit && state.selectedCustomer == null) return null;
    
    return () {
       context.read<SalesBloc>().add(ClearCart()); // Ensure cart is clean for single sale from sheet
       context.read<SalesBloc>().add(AddToCart(_selectedProduct!.copyWith(sellingPrice: double.tryParse(_priceController.text) ?? _selectedProduct!.sellingPrice), quantity: qty.toInt()));
       context.read<SalesBloc>().add(CheckoutSale(
         discount: double.tryParse(_discountController.text) ?? 0,
         paidAmount: state.paymentType == PaymentType.cash ? finalTotal : 0,
         notes: _notesController.text,
       ));
    };
  }

  void _showSearchablePicker<T>({required String title, required List<T> items, required String Function(T) itemLabel, String Function(T)? itemSublabel, required Function(T) onSelected, required String hintText}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = items.where((item) => itemLabel(item).toLowerCase().contains(query.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setPickerState(() => query = v),
                    decoration: InputDecoration(hintText: hintText, prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(itemLabel(filtered[index])),
                        subtitle: itemSublabel != null ? Text(itemSublabel(filtered[index])) : null,
                        onTap: () {
                          onSelected(filtered[index]);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নতুন গ্রাহক যোগ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'নাম *')),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) return;
              
              final db = context.read<DatabaseHelper>();
              final database = await db.database;
              
              final id = await database.insert(DatabaseConstants.tableCustomers, {
                DatabaseConstants.colName: nameController.text,
                DatabaseConstants.colPhone: phoneController.text,
                DatabaseConstants.colCustomerType: 'customer',
                DatabaseConstants.colCurrentCreditBalance: 0.0,
                DatabaseConstants.colTotalCredit: 0.0,
                DatabaseConstants.colTotalPaid: 0.0,
                DatabaseConstants.colTotalPurchases: 0.0,
                DatabaseConstants.colIsActive: 1,
                DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
                DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
                DatabaseConstants.colIsSynced: 0,
              });

              final newCustomer = Customer(
                id: id,
                name: nameController.text,
                phone: phoneController.text,
                address: '',
                currentCreditBalance: 0,
                totalPurchases: 0,
                isActive: true,
              );

              if (!context.mounted) return;
              context.read<CustomerBloc>().add(LoadCustomers());
              context.read<SalesBloc>().add(SelectCustomer(newCustomer));
              Navigator.pop(context);
            },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }
}
