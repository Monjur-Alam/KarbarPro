import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sales_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/domain/product.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () {
              context.read<SalesBloc>().add(ClearCart());
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Side: Product List
          Expanded(
            flex: 3,
            child: BlocBuilder<InventoryBloc, InventoryState>(
              builder: (context, state) {
                if (state is InventoryLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is InventoryLoaded) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Adjust for tablet/mobile
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: state.products.length,
                    itemBuilder: (context, index) {
                      final product = state.products[index];
                      return _ProductCard(
                        product: product,
                        onTap: () {
                          context.read<SalesBloc>().add(AddToCart(product));
                        },
                      );
                    },
                  );
                }
                return const Center(child: Text('No products available'));
              },
            ),
          ),
          
          // Right Side: Cart
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                   Container(
                     padding: const EdgeInsets.all(16),
                     color: Colors.blue.shade50,
                     child: const Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text('Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                         Icon(Icons.shopping_cart),
                       ],
                     ),
                   ),
                   Expanded(
                     child: BlocBuilder<SalesBloc, SalesState>(
                       builder: (context, state) {
                         List<CartItem> items = [];
                         if (state is SalesCartUpdate) items = state.items;
                         
                         if (items.isEmpty) {
                           return const Center(child: Text('Cart is empty'));
                         }

                         return ListView.separated(
                           itemCount: items.length,
                           separatorBuilder: (context, index) => const Divider(),
                           itemBuilder: (context, index) {
                             final item = items[index];
                             return ListTile(
                               title: Text(item.product.name),
                               subtitle: Text('${item.quantity} x ৳${item.product.price}'),
                               trailing: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Text('৳${item.subTotal.toStringAsFixed(2)}', 
                                     style: const TextStyle(fontWeight: FontWeight.bold)),
                                   IconButton(
                                     icon: const Icon(Icons.remove_circle_outline),
                                     onPressed: () {
                                        context.read<SalesBloc>().add(UpdateCartQuantity(
                                          item.product.id, 
                                          item.quantity - 1,
                                        ));
                                     },
                                   ),
                                 ],
                               ),
                             );
                           },
                         );
                       },
                     ),
                   ),
                   _CartSummarySection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Text(
                    product.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Stock: ${product.stockQuantity}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${product.price}',
                    style: const TextStyle(
                      color: Colors.green, 
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sale completed! Invoice: ${state.invoiceId}')),
          );
        } else if (state is SalesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        double total = 0;
        if (state is SalesCartUpdate) total = state.totalAmount;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
               BoxShadow(
                 color: Colors.grey.withValues(alpha: 0.2),
                 blurRadius: 10,
                 offset: const Offset(0, -5),
               ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:', style: TextStyle(fontSize: 16)),
                  Text(
                    '৳${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: total > 0 
                      ? () => context.read<SalesBloc>().add(
                            CheckoutSale(paidAmount: total), // Simple checkout for now
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Checkout', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
