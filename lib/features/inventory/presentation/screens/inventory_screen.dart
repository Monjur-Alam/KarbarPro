import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ইনভেন্টরি', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is InventoryLoaded) {
            return Column(
              children: [
                _buildSearchAndSort(context, state),
                _buildFilterChips(context, state),
                Expanded(
                  child: state.products.isEmpty
                      ? _buildEmptyState()
                      : _buildProductList(state.products),
                ),
              ],
            );
          } else if (state is InventoryError) {
            return Center(child: Text('ত্রুটি: ${state.message}'));
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditProductDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('নতুন আইটেম যোগ'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Widget _buildSearchAndSort(BuildContext context, InventoryLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                context.read<InventoryBloc>().add(LoadProducts(
                  searchQuery: query.isEmpty ? null : query,
                  category: state.category,
                  stockFilter: state.stockFilter,
                  sortBy: state.sortBy,
                ));
              },
              decoration: InputDecoration(
                hintText: 'পণ্য অনুসন্ধান করুন...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.sort),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              padding: const EdgeInsets.all(12),
            ),
            onPressed: () => _showSortBottomSheet(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, InventoryLoaded state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          _buildFilterDropdown(
            context,
            label: 'শ্রেণী',
            value: state.category ?? 'All',
            items: state.allCategories.isEmpty ? ['All'] : state.allCategories,
            onChanged: (value) {
              context.read<InventoryBloc>().add(LoadProducts(
                searchQuery: state.searchQuery,
                category: value == 'All' ? null : value,
                stockFilter: state.stockFilter,
                sortBy: state.sortBy,
              ));
            },
          ),
          const SizedBox(width: 12),
          _buildFilterDropdown(
            context,
            label: 'স্টক',
            value: state.stockFilter ?? 'All',
            items: const ['All', 'low', 'out'],
            displayNames: const {'All': 'সব', 'low': 'কম', 'out': 'শেষ'},
            onChanged: (value) {
              context.read<InventoryBloc>().add(LoadProducts(
                searchQuery: state.searchQuery,
                category: state.category,
                stockFilter: value == 'All' ? null : value,
                sortBy: state.sortBy,
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> items,
    Map<String, String>? displayNames,
    required Function(String) onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                displayNames?[item] ?? item,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (val) => val != null ? onChanged(val) : null,
        ),
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final stockColor = product.currentStock <= 0
        ? Colors.red
        : product.currentStock <= product.minStockAlert
            ? Colors.orange
            : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAddEditProductDialog(context, product: product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    radius: 20,
                    child: Text(
                      product.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (product.category != null && product.category!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.category!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoColumn('বিক্রয়', '৳${_toBengaliDigits(product.sellingPrice.toStringAsFixed(0))}', Colors.green),
                  _buildInfoColumn('ক্রয়', '৳${_toBengaliDigits(product.purchasePrice.toStringAsFixed(0))}', Colors.blue),
                  _buildInfoColumn('পরিমাণ', '${_toBengaliDigits(product.currentStock.toString())} ${product.unit}', stockColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'কোনো পণ্য পাওয়া যায়নি',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'নতুন পণ্য যোগ করতে নিচের বাটনে ক্লিক করুন',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showSortBottomSheet(BuildContext context, InventoryLoaded state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'সাজান:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSortOption(context, state, 'latest', 'সর্বশেষ', Icons.access_time),
              _buildSortOption(context, state, 'quantity_high', 'পরিমাণ (বেশি থেকে কম)', Icons.arrow_downward),
              _buildSortOption(context, state, 'quantity_low', 'পরিমাণ (কম থেকে বেশি)', Icons.arrow_upward),
              _buildSortOption(context, state, 'name_asc', 'নাম (A-Z)', Icons.sort_by_alpha),
              _buildSortOption(context, state, 'name_desc', 'নাম (Z-A)', Icons.sort_by_alpha),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(BuildContext context, InventoryLoaded state, String sortValue, String label, IconData icon) {
    final isSelected = state.sortBy == sortValue;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.black,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        context.read<InventoryBloc>().add(LoadProducts(
          searchQuery: state.searchQuery,
          category: state.category,
          stockFilter: state.stockFilter,
          sortBy: sortValue,
        ));
        Navigator.pop(context);
      },
    );
  }

  void _showAddEditProductDialog(BuildContext context, {Product? product}) {
    final nameController = TextEditingController(text: product?.name);
    final sellingPriceController = TextEditingController(text: product?.sellingPrice.toString());
    final purchasePriceController = TextEditingController(text: product?.purchasePrice.toString());
    final stockController = TextEditingController(text: product?.currentStock.toString());
    final unitController = TextEditingController(text: product?.unit);
    final categoryController = TextEditingController(text: product?.category);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(product == null ? 'নতুন পণ্য যোগ করুন' : 'পণ্য সম্পাদনা করুন'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'পণ্যের নাম *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sellingPriceController,
                decoration: const InputDecoration(
                  labelText: 'বিক্রয় মূল্য *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: purchasePriceController,
                decoration: const InputDecoration(
                  labelText: 'ক্রয় মূল্য *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: 'স্টক পরিমাণ *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'একক (pcs, kg, ইত্যাদি)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'শ্রেণী (ঐচ্ছিক)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text;
              final sellingPrice = double.tryParse(sellingPriceController.text) ?? 0.0;
              final purchasePrice = double.tryParse(purchasePriceController.text) ?? 0.0;
              final stock = int.tryParse(stockController.text) ?? 0;
              final unit = unitController.text.isEmpty ? 'pcs' : unitController.text;
              final category = categoryController.text;

              if (name.isNotEmpty && sellingPrice > 0) {
                final newProduct = Product(
                  id: product?.id,
                  name: name,
                  sellingPrice: sellingPrice,
                  purchasePrice: purchasePrice,
                  currentStock: stock,
                  unit: unit,
                  category: category.isEmpty ? null : category,
                  createdAt: product?.createdAt,
                  updatedAt: DateTime.now(),
                );

                if (product == null) {
                  context.read<InventoryBloc>().add(AddProduct(newProduct));
                } else {
                  context.read<InventoryBloc>().add(UpdateProduct(newProduct));
                }
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }
}
