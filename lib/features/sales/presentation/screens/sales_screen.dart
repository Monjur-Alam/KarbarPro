import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:amar_dokan/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:amar_dokan/features/customers/presentation/bloc/customer_bloc.dart';
import 'package:amar_dokan/features/customers/domain/customer.dart';
import 'package:amar_dokan/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:amar_dokan/features/inventory/domain/product.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    context.read<InventoryBloc>().add(LoadProducts());
    context.read<CustomerBloc>().add(LoadCustomers());
    context.read<SalesBloc>().add(LoadSalesInitialData());
  }


  @override
  void dispose() {
    _productSearchController.dispose();
    _customerSearchController.dispose();
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
    setState(() {
      _selectedProduct = product;
      _priceController.text = product.sellingPrice.toStringAsFixed(0);
      _quantityController.text = '1';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProduct = null;
      _productSearchController.clear();
      _priceController.clear();
      _quantityController.text = '1';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('বিক্রয় সম্পন্ন হয়েছে! ইনভয়েস: ${_toBengaliDigits(state.invoiceId)}'),
              backgroundColor: Colors.green,
            ),
          );
          _clearSelection();
          _paidAmountController.clear();
          _discountController.text = '0';
          _notesController.clear();
        } else if (state is SalesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        if (state is SalesDataLoaded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('পণ্য বিক্রয় করুন', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                if (state.cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                    onPressed: () => _showClearCartDialog(context),
                  ),
              ],
            ),
            body: Column(
              children: [
                _buildSummaryBar(state.todayTotalSales),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModeAndPaymentToggles(state),
                        const SizedBox(height: 20),
                        if (state.paymentType == PaymentType.credit) ...[
                          _buildSectionTitle('গ্রাহক নির্বাচন করুন'),
                          const SizedBox(height: 8),
                          _buildCustomerSelector(state.selectedCustomer),
                          const SizedBox(height: 20),
                        ],
                        _buildSectionTitle('পণ্য নির্বাচন ও পরিমাণ'),
                        const SizedBox(height: 8),
                        _buildProductSelectorAndInputs(state),
                        const SizedBox(height: 24),
                        if (state.mode == SalesMode.multiple) ...[
                          _buildSectionTitle('কার্ট তালিকা (${_toBengaliDigits(state.cart.length.toString())})'),
                          const SizedBox(height: 8),
                          _buildCartList(state.cart),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildCheckoutSection(state),
              ],
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildSummaryBar(double todayTotal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.today, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'আজকের মোট বিক্রি: ৳${_toBengaliDigits(NumberFormat('#,##,###').format(todayTotal))}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          const Icon(Icons.cloud_done, size: 18, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildModeAndPaymentToggles(SalesDataLoaded state) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('বিক্রয় মোড', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              SegmentedButton<SalesMode>(
                segments: const [
                  ButtonSegment(value: SalesMode.single, label: Text('একক পণ্য')),
                  ButtonSegment(value: SalesMode.multiple, label: Text('একাধিক পণ্য')),
                ],
                selected: {state.mode},
                onSelectionChanged: (Set<SalesMode> newSelection) {
                  context.read<SalesBloc>().add(ToggleSalesMode(newSelection.first));
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('পেমেন্ট ধরণ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildPaymentButton(
                    'নগদ',
                    Icons.payments_outlined,
                    state.paymentType == PaymentType.cash,
                    Colors.green,
                    () => context.read<SalesBloc>().add(const TogglePaymentType(PaymentType.cash)),
                  ),
                  const SizedBox(width: 8),
                  _buildPaymentButton(
                    'বাকি',
                    Icons.history_toggle_off,
                    state.paymentType == PaymentType.credit,
                    Colors.red,
                    () => context.read<SalesBloc>().add(const TogglePaymentType(PaymentType.credit)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton(String label, IconData icon, bool isSelected, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              Text(label, style: TextStyle(color: isSelected ? color : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSelector(Customer? selectedCustomer) {
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        List<Customer> customers = [];
        if (state is CustomerLoaded) customers = state.customers;

        return Autocomplete<Customer>(
          displayStringForOption: (c) => '${c.name} (${c.phone})',
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable<Customer>.empty();
            return customers.where((c) => 
              c.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
              c.phone.contains(textEditingValue.text)
            );
          },
          onSelected: (Customer customer) {
            context.read<SalesBloc>().add(SelectCustomer(customer));
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (selectedCustomer != null && controller.text.isEmpty) {
              controller.text = '${selectedCustomer.name} (${selectedCustomer.phone})';
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'গ্রাহক খুঁজুন...',
                prefixIcon: const Icon(Icons.person_search),
                suffixIcon: selectedCustomer != null 
                  ? IconButton(
                      icon: const Icon(Icons.clear), 
                      onPressed: () {
                        controller.clear();
                        context.read<SalesBloc>().add(const SelectCustomer(null));
                      }
                    ) 
                  : IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showAddCustomerDialog(context)),
                border: const OutlineInputBorder(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductSelectorAndInputs(SalesDataLoaded state) {
    return Column(
      children: [
        BlocBuilder<InventoryBloc, InventoryState>(
          builder: (context, invState) {
            List<Product> products = [];
            if (invState is InventoryLoaded) products = invState.products;

            return Autocomplete<Product>(
              displayStringForOption: (p) => p.name,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                return products.where((p) => p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) && p.currentStock > 0);
              },
              onSelected: _onProductSelected,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'পণ্য খুঁজুন...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: Icon(Icons.qr_code_scanner),
                    border: OutlineInputBorder(),
                  ),
                );
              },
            );
          },
        ),
        if (_selectedProduct != null) ...[
          const SizedBox(height: 16),
          _buildProductDetailCard(state),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'বিক্রয় মূল্য', prefixText: '৳', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        int q = int.tryParse(_quantityController.text) ?? 1;
                        if (q > 1) _quantityController.text = (q - 1).toString();
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'পরিমাণ', border: OutlineInputBorder()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        int q = int.tryParse(_quantityController.text) ?? 1;
                        if (q < _selectedProduct!.currentStock) {
                          _quantityController.text = (q + 1).toString();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final qty = int.tryParse(_quantityController.text) ?? 1;
                final price = double.tryParse(_priceController.text) ?? _selectedProduct!.sellingPrice;
                
                // Temporary product override with user price
                final productWithPrice = _selectedProduct!.copyWith(sellingPrice: price);
                
                context.read<SalesBloc>().add(AddToCart(productWithPrice, quantity: qty));
                
                if (state.mode == SalesMode.single) {
                  // Stay selected but maybe scroll to checkout
                } else {
                  _clearSelection();
                }
              },
              icon: Icon(state.mode == SalesMode.single ? Icons.shopping_basket : Icons.add_shopping_cart),
              label: Text(state.mode == SalesMode.single ? 'সারসংক্ষেপ দেখুন' : 'কার্টে যোগ করুন'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductDetailCard(SalesDataLoaded state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(_selectedProduct!.name[0].toUpperCase(), style: const TextStyle(color: Colors.blue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'স্টক: ${_toBengaliDigits(_selectedProduct!.currentStock.toString())} ${_selectedProduct!.unit}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '৳${_toBengaliDigits(_selectedProduct!.sellingPrice.toStringAsFixed(0))}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearSelection),
        ],
      ),
    );
  }

  Widget _buildCartList(List<CartItem> cart) {
    if (cart.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('কার্ট ফাঁকা')));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final item = cart[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item.product.name),
            subtitle: Text(
              '${_toBengaliDigits(item.quantity.toString())} x ৳${_toBengaliDigits(item.product.sellingPrice.toStringAsFixed(0))}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '৳${_toBengaliDigits(item.subTotal.toStringAsFixed(0))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => context.read<SalesBloc>().add(UpdateCartQuantity(item.product.id!, item.quantity - 1)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    if (item.quantity < item.product.currentStock) {
                      context.read<SalesBloc>().add(UpdateCartQuantity(item.product.id!, item.quantity + 1));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection(SalesDataLoaded state) {
    double total = state.totalAmount;
    double discount = double.tryParse(_discountController.text) ?? 0;
    double finalTotal = total - discount;
    if (finalTotal < 0) finalTotal = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ছাড় (৳)', border: OutlineInputBorder()),
                  onChanged: (v) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('মোট পরিশোধযোগ্য', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '৳${_toBengaliDigits(finalTotal.toStringAsFixed(0))}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.paymentType == PaymentType.credit) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _paidAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'জমা পরিমাণ (ঐচ্ছিক)',
                hintText: 'কত টাকা জমা দিয়েছেন?',
                prefixText: '৳',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isSubmitting || (state.cart.isEmpty && _selectedProduct == null)
                  ? null
                  : () {
                      final paid = double.tryParse(_paidAmountController.text) ?? 
                                  (state.paymentType == PaymentType.cash ? finalTotal : 0.0);
                      
                      context.read<SalesBloc>().add(CheckoutSale(
                        discount: discount,
                        paidAmount: paid,
                        notes: _notesController.text,
                      ));
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: state.paymentType == PaymentType.cash ? Colors.green.shade700 : Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: state.isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'বিক্রয় সম্পন্ন করুন (৳${_toBengaliDigits(finalTotal.toStringAsFixed(0))})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('কার্ট পরিষ্কার করুন?'),
        content: const Text('আপনি কি নিশ্চিত যে আপনি কার্টের সব পণ্য মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('না')),
          TextButton(
            onPressed: () {
              context.read<SalesBloc>().add(ClearCart());
              Navigator.pop(context);
            },
            child: const Text('হ্যাঁ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নতুন গ্রাহক যোগ করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'নাম')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'ফোন নম্বর'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                context.read<CustomerBloc>().add(AddCustomer(Customer(name: nameCtrl.text, phone: phoneCtrl.text)));
                Navigator.pop(context);
              }
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }
}
