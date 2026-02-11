import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/product.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টক বা ইনভেন্টরি', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is InventoryLoaded) {
            if (state.products.isEmpty) {
              return const Center(child: Text('No products found. Add one!'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.products.length,
              itemBuilder: (context, index) {
                final product = state.products[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text(product.name[0].toUpperCase()),
                    ),
                     title: Text(product.name),
                     subtitle: Text('Stock: ${product.currentStock} ${product.unit}'),
                     trailing: Text(
                       '৳${product.sellingPrice}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      _showAddEditProductDialog(context, product: product);
                    },
                  ),
                );
              },
            );
          } else if (state is InventoryError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditProductDialog(context),
        child: const Icon(Icons.add),
      ),
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
        title: Text(product == null ? 'Add Product' : 'Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
               const SizedBox(height: 16),
               TextField(
                 controller: sellingPriceController,
                 decoration: const InputDecoration(labelText: 'Selling Price'),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: purchasePriceController,
                 decoration: const InputDecoration(labelText: 'Purchase Price'),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: stockController,
                 decoration: const InputDecoration(labelText: 'Stock Quantity'),
                 keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: unitController,
                 decoration: const InputDecoration(labelText: 'Unit (pcs, kg, etc.)'),
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: categoryController,
                 decoration: const InputDecoration(labelText: 'Category (Optional)'),
               ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
                   category: category,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
