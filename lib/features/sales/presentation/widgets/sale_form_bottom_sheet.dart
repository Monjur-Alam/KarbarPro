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
import '../../../../core/l10n/app_localizations.dart';

class SaleFormBottomSheet extends StatefulWidget {
  const SaleFormBottomSheet({super.key});

  @override
  State<SaleFormBottomSheet> createState() => _SaleFormBottomSheetState();
}

class _SaleFormBottomSheetState extends State<SaleFormBottomSheet> {
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  
  Product? _selectedProduct;
  bool _isPartialPayment = false;

  @override
  void initState() {
    super.initState();
    // Clear cart when opening for a new sale
    context.read<SalesBloc>().add(ClearCart());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onProductSelected(Product product) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedProduct = product;
      _priceController.text = product.sellingPrice.toStringAsFixed(0);
      _quantityController.text = '1';
    });
  }

  void _addItemToCart() {
    if (_selectedProduct == null) return;
    
    final qty = int.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) return;

    final price = double.tryParse(_priceController.text) ?? _selectedProduct!.sellingPrice;
    
    // Create a temporary product with the modified price if needed
    final productToAdd = _selectedProduct!.copyWith(sellingPrice: price);
    
    context.read<SalesBloc>().add(AddToCart(productToAdd, quantity: qty));
    
    HapticFeedback.lightImpact();
    setState(() {
      _selectedProduct = null;
      _quantityController.text = '1';
      _priceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          Navigator.pop(context); // Close on success
        } else if (state is SalesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        if (state is! SalesDataLoaded) return const Center(child: CircularProgressIndicator());

        double subTotal = state.totalAmount;
        double discount = double.tryParse(_discountController.text) ?? 0;
        double finalTotal = subTotal - discount;
        if (finalTotal < 0) finalTotal = 0;

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                      const Text('নতুন বিক্রয় (ইনভয়েস)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Product Selection Section
                  _buildSectionHeader('📦 পণ্য নির্বাচন করুন', Colors.blue),
                  const SizedBox(height: 12),
                  _buildProductSelector(),
                  
                  if (_selectedProduct != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildQtyBtn(Icons.remove, () {
                                int current = int.tryParse(_quantityController.text) ?? 1;
                                if (current > 1) {
                                  setState(() => _quantityController.text = (current - 1).toString());
                                }
                              }),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTextField(
                                  _quantityController, 
                                  'পরিমাণ *', 
                                  suffix: _selectedProduct!.unit, 
                                  isNumber: true, 
                                  textAlign: TextAlign.center, 
                                  onChanged: (_) => setState(() {})
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildQtyBtn(Icons.add, () {
                                int current = int.tryParse(_quantityController.text) ?? 0;
                                setState(() => _quantityController.text = (current + 1).toString());
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_priceController, 'মূল্য (একক) *', prefix: '৳', isNumber: true, onChanged: (_) => setState(() {}))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addItemToCart,
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('কার্টে যোগ করুন'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],

                  // Cart Summary Section
                  if (state.cart.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('🛒 কার্ট তালিকা (${context.l10n.formatDigits(state.cart.length.toString())}টি)', Colors.purple),
                    const SizedBox(height: 8),
                    _buildCartList(state),
                  ],

                  // Payment Section
                  const SizedBox(height: 24),
                  _buildSectionHeader('💳 পেমেন্ট তথ্য', Colors.green),
                  const SizedBox(height: 12),
                  _buildPaymentTypeToggle(state),
                  
                  const SizedBox(height: 16),
                  if (state.paymentType == PaymentType.credit) ...[
                    _buildCustomerSelector(state.selectedCustomer),
                    const SizedBox(height: 16),
                    _buildPartialPaymentSection(finalTotal),
                  ] else ...[
                    _buildTextField(_discountController, 'ডিসকাউন্ট (টাকা)', prefix: '৳', isNumber: true, onChanged: (_) => setState(() {})),
                  ],

                  const SizedBox(height: 16),
                  _buildTextField(_notesController, '💬 অতিরিক্ত নোট (ঐচ্ছিক)', maxLines: 2),
                  
                  const SizedBox(height: 32),
                  _buildCheckoutSummary(state, finalTotal),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('বাতিল'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: state.isSubmitting || state.cart.isEmpty ? null : () => _handleCheckout(state, finalTotal),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: state.isSubmitting 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('বিক্রয় সম্পন্ন করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
      ],
    );
  }

  Widget _buildCartList(SalesDataLoaded state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.cart.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final item = state.cart[index];
          return ListTile(
            contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
            title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            subtitle: Text(
              '${context.l10n.formatDigits(item.quantity.toString())} ${item.product.unit} × ৳${context.l10n.formatAmount(item.product.sellingPrice)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '৳${context.l10n.formatAmount(item.subTotal)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  onPressed: () {
                    context.read<SalesBloc>().add(RemoveFromCart(item.product.id!));
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPartialPaymentSection(double finalTotal) {
    return Column(
      children: [
        CheckboxListTile(
          value: _isPartialPayment,
          onChanged: (v) => setState(() {
            _isPartialPayment = v ?? false;
            if (!_isPartialPayment) _paidAmountController.text = '0';
          }),
          title: const Text('নগদ আদায় হয়েছে?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        if (_isPartialPayment)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildTextField(_paidAmountController, 'আদায়ের পরিমাণ', prefix: '৳', isNumber: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_discountController, 'ডিসকাউন্ট', prefix: '৳', isNumber: true, onChanged: (_) => setState(() {}))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCheckoutSummary(SalesDataLoaded state, double finalTotal) {
    double paid = double.tryParse(_paidAmountController.text) ?? 0;
    if (state.paymentType == PaymentType.cash) paid = finalTotal;
    
    double due = finalTotal - paid;
    if (due < 0) due = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildSummaryRow('উপ-মোট:', '৳${context.l10n.formatAmount(state.totalAmount)}', Colors.white70),
          _buildSummaryRow('ডিসকাউন্ট:', '- ৳${context.l10n.formatAmount(double.tryParse(_discountController.text) ?? 0)}', Colors.red.shade300),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white24)),
          _buildSummaryRow('সর্বমোট দেয়:', '৳${context.l10n.formatAmount(finalTotal)}', Colors.white, isBold: true, fontSize: 20),
          if (state.paymentType == PaymentType.credit) ...[
             const SizedBox(height: 8),
             _buildSummaryRow('আদায়কৃত:', '৳${context.l10n.formatAmount(paid)}', Colors.green.shade300),
             _buildSummaryRow('বাকি থাকবে:', '৳${context.l10n.formatAmount(due)}', Colors.orange.shade300),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 36, 
      height: 36,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: Colors.blue.shade800),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  void _handleCheckout(SalesDataLoaded state, double finalTotal) {
    if (state.paymentType == PaymentType.credit && state.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('গ্রাহক নির্বাচন করুন!'), backgroundColor: Colors.orange));
      return;
    }

    double paid = double.tryParse(_paidAmountController.text) ?? 0;
    if (state.paymentType == PaymentType.cash) paid = finalTotal;
    
    context.read<SalesBloc>().add(CheckoutSale(
      discount: double.tryParse(_discountController.text) ?? 0,
      paidAmount: paid,
      notes: _notesController.text,
    ));
  }

  Widget _buildTextField(TextEditingController controller, String label, {String? prefix, String? suffix, bool isNumber = false, int maxLines = 1, TextAlign textAlign = TextAlign.start, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      textAlign: textAlign,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            itemSublabel: (p) => 'স্টক: ${context.l10n.formatDigits(p.currentStock.toString())} ${p.unit}',
            onSelected: _onProductSelected,
            hintText: 'পণ্য খুঁজুন...',
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.3),
              border: Border.all(color: _selectedProduct != null ? Colors.blue : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: _selectedProduct != null ? Colors.blue : Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(child: Text(_selectedProduct?.name ?? 'পণ্য নির্বাচন করুন...', style: TextStyle(color: _selectedProduct != null ? Colors.blue.shade900 : Colors.grey.shade600, fontWeight: _selectedProduct != null ? FontWeight.bold : FontWeight.normal))),
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
        onTap: () {
           context.read<SalesBloc>().add(TogglePaymentType(type));
           if (type == PaymentType.cash) {
             setState(() => _isPartialPayment = false);
             _paidAmountController.text = '0';
           }
        },
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
        if (state is CustomerLoaded) {
          customers = state.customers.where((c) => c.type == 'customer').toList();
        }

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
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50.withOpacity(0.3),
                    border: Border.all(color: selectedCustomer != null ? Colors.orange : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: selectedCustomer != null ? Colors.orange : Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(child: Text(selectedCustomer?.name ?? 'গ্রাহক নির্বাচন করুন...', style: TextStyle(color: selectedCustomer != null ? Colors.orange.shade900 : Colors.grey.shade600, fontWeight: selectedCustomer != null ? FontWeight.bold : FontWeight.normal))),
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

  void _showSearchablePicker<T>({required String title, required List<T> items, required String Function(T) itemLabel, String Function(T)? itemSublabel, required Function(T) onSelected, required String hintText}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = items.where((item) => itemLabel(item).toLowerCase().contains(query.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 20),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setPickerState(() => query = v),
                    decoration: InputDecoration(hintText: hintText, prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), contentPadding: EdgeInsets.zero),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty 
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 48, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('কোনো তথ্য পাওয়া যায়নি', style: TextStyle(color: Colors.grey))]))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(itemLabel(filtered[index]), style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: itemSublabel != null ? Text(itemSublabel(filtered[index])) : null,
                            trailing: const Icon(Icons.chevron_right, size: 18),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('নতুন গ্রাহক যোগ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'নাম *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ফোন নম্বর *', border: OutlineInputBorder())),
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
