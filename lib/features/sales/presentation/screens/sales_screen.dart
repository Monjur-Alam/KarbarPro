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
import 'package:amar_dokan/core/services/connectivity_service.dart';
import 'package:amar_dokan/features/dashboard/presentation/bloc/home_bloc.dart';
import 'package:amar_dokan/features/reports/presentation/bloc/report_bloc.dart';

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
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final FocusNode _productFocusNode = FocusNode();
  final FocusNode _customerFocusNode = FocusNode();

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
    _productFocusNode.dispose();
    _customerFocusNode.dispose();
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
    
    // In single mode, automatically add to cart (this will replace any previous item)
    final currentState = context.read<SalesBloc>().state;
    if (currentState is SalesDataLoaded && currentState.mode == SalesMode.single) {
      context.read<SalesBloc>().add(ClearCart()); // Clear previous
      context.read<SalesBloc>().add(AddToCart(product, quantity: 1));
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProduct = null;
      _productSearchController.clear();
      _priceController.clear();
      _quantityController.text = '1';
    });
    
    // In single mode, also clear the cart when selection is cleared
    final currentState = context.read<SalesBloc>().state;
    if (currentState is SalesDataLoaded && currentState.mode == SalesMode.single) {
      context.read<SalesBloc>().add(ClearCart());
    }
    
    _productFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          HapticFeedback.heavyImpact();
          _showSaleSuccessDialog(context, state.sale);
          _clearSelection();
          _paidAmountController.clear();
          _discountController.text = '0';
          _notesController.clear();
          
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
            title: const Text('পণ্য বিক্রয় করুন', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (state is SalesDataLoaded && state.cart.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                  onPressed: () => _showClearCartDialog(context),
                ),
            ],
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
      return Column(
        children: [
          _buildConnectivityBanner(),
          _buildSummaryBar(state.todayTotalSales),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeAndPaymentToggles(state),
                  const SizedBox(height: 16),
                  if (state.paymentType == PaymentType.credit) ...[
                    _buildSectionTitle('গ্রাহক নির্বাচন করুন'),
                    const SizedBox(height: 8),
                    _buildCustomerSelector(state.selectedCustomer),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionTitle('পণ্য নির্বাচন ও পরিমাণ'),
                  const SizedBox(height: 8),
                  _buildProductSelectorAndInputs(state),
                  const SizedBox(height: 20),
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
      );
    }
    
    return const Center(child: Text('বিক্রয় ডাটা লোড করা যাচ্ছে না'));
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('কার্ট খালি করুন'),
        content: const Text('আপনি কি নিশ্চিত যে আপনি কার্ট থেকে সব পণ্য মুছে ফেলতে চান?'),
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
                  HapticFeedback.selectionClick();
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
                    () {
                      HapticFeedback.selectionClick();
                      context.read<SalesBloc>().add(const TogglePaymentType(PaymentType.cash));
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPaymentButton(
                    'বাকি',
                    Icons.history_toggle_off,
                    state.paymentType == PaymentType.credit,
                    Colors.red,
                    () {
                      HapticFeedback.selectionClick();
                      context.read<SalesBloc>().add(const TogglePaymentType(PaymentType.credit));
                      _customerFocusNode.requestFocus();
                    },
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

        final displayValue = selectedCustomer != null 
            ? '${selectedCustomer.name} (${selectedCustomer.phone})' 
            : 'গ্রাহক নির্বাচন করুন...';

        return InkWell(
          onTap: () {
            _showSearchablePicker<Customer>(
              title: 'গ্রাহক নির্বাচন করুন',
              items: customers,
              itemLabel: (c) => c.name,
              itemSublabel: (c) => c.phone,
              onSelected: (Customer customer) {
                HapticFeedback.selectionClick();
                context.read<SalesBloc>().add(SelectCustomer(customer));
                _productFocusNode.requestFocus();
              },
              hintText: 'গ্রাহক খুঁজুন...',
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      color: selectedCustomer != null ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                       context.read<SalesBloc>().add(const SelectCustomer(null));
                    },
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showAddCustomerDialog(context),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
              ],
            ),
          ),
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
            if (invState is InventoryLoaded) {
              products = invState.products.where((p) => p.currentStock > 0).toList();
            }

            return InkWell(
              onTap: () {
                _showSearchablePicker<Product>(
                  title: 'পণ্য নির্বাচন করুন',
                  items: products,
                  itemLabel: (p) => p.name,
                  itemSublabel: (p) => 'স্টক: ${_toBengaliDigits(p.currentStock.toString())} ${p.unit}',
                  onSelected: _onProductSelected,
                  hintText: 'পণ্য খুঁজুন...',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedProduct != null 
                            ? _selectedProduct!.name 
                            : 'পণ্য নির্বাচন করুন...',
                        style: TextStyle(
                          color: _selectedProduct != null ? Colors.black : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
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
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.blue),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          int q = int.tryParse(_quantityController.text) ?? 1;
                          if (q > 1) _quantityController.text = (q - 1).toString();
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _quantityController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          int q = int.tryParse(_quantityController.text) ?? 1;
                          if (q < _selectedProduct!.currentStock) {
                            _quantityController.text = (q + 1).toString();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                final qty = int.tryParse(_quantityController.text) ?? 1;
                final price = double.tryParse(_priceController.text) ?? _selectedProduct!.sellingPrice;
                
                final productWithPrice = _selectedProduct!.copyWith(sellingPrice: price);
                context.read<SalesBloc>().add(AddToCart(productWithPrice, quantity: qty));
                
                if (state.mode == SalesMode.multiple) {
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
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            title: Text(item.product.name),
            subtitle: Text(
              '${_toBengaliDigits(item.quantity.toString())} x ৳${_toBengaliDigits(item.product.sellingPrice.toStringAsFixed(0))}',
              style: const TextStyle(color: Colors.blueGrey),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQtyAction(Icons.remove, () {
                    HapticFeedback.lightImpact();
                    context.read<SalesBloc>().add(UpdateCartQuantity(item.product.id!, item.quantity - 1));
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _toBengaliDigits(item.quantity.toString()),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  _buildQtyAction(Icons.add, () {
                    HapticFeedback.lightImpact();
                    if (item.quantity < item.product.currentStock) {
                      context.read<SalesBloc>().add(UpdateCartQuantity(item.product.id!, item.quantity + 1));
                    }
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQtyAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.blue),
      ),
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
      child: SafeArea(
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
                      FittedBox(
                        child: Text(
                          '৳${_toBengaliDigits(finalTotal.toStringAsFixed(0))}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
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
                        HapticFeedback.mediumImpact();
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
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'বিক্রয় সম্পন্ন করুন (৳${_toBengaliDigits(finalTotal.toStringAsFixed(0))})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
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
            child: const Text('নতুন বিক্রয়', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailsScreen(saleId: sale.id)));
            },
            child: const Text('বিক্রি দেখুন'),
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

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87));
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
                HapticFeedback.selectionClick();
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
  void _showSearchablePicker<T>({
    required String title,
    required List<T> items,
    required String Function(T) itemLabel,
    required String Function(T) itemSublabel,
    required void Function(T) onSelected,
    String? hintText,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchablePicker<T>(
        title: title,
        items: items,
        itemLabel: itemLabel,
        itemSublabel: itemSublabel,
        onSelected: onSelected,
        hintText: hintText,
      ),
    );
  }
}

class _SearchablePicker<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T) itemSublabel;
  final void Function(T) onSelected;
  final String? hintText;

  const _SearchablePicker({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.itemSublabel,
    required this.onSelected,
    this.hintText,
  });

  @override
  State<_SearchablePicker<T>> createState() => _SearchablePickerState<T>();
}

class _SearchablePickerState<T> extends State<_SearchablePicker<T>> {
  late List<T> _filteredItems;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filter(String query) {
    setState(() {
      _filteredItems = widget.items
          .where((item) =>
              widget.itemLabel(item).toLowerCase().contains(query.toLowerCase()) ||
              widget.itemSublabel(item).toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'খুঁজুন...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: _filteredItems.isEmpty 
              ? const Center(child: Text('কোনো তথ্য পাওয়া যায়নি'))
              : ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return ListTile(
                  title: Text(widget.itemLabel(item), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(widget.itemSublabel(item)),
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
