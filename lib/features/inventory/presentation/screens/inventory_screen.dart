import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/product.dart';
import '../../domain/product_variant.dart';
import 'manage_category_screen.dart';
import 'product_form_sheet.dart';
import '../../../../core/l10n/app_localizations.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                        ? _buildEmptyState(context)
                        : _buildProductList(context, state.products),
                  ),
                ],
              );
            } else if (state is InventoryError) {
              return Center(child: Text('${context.l10n.errorPrefix}${state.message}'));
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEditProductDialog(context),
          icon: const Icon(Icons.add, size: 20,),
          label: Text(context.l10n.addNewItem),
        ),
      ),
    );
  }

  Widget _buildSearchAndSort(BuildContext context, InventoryLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                hintText: context.l10n.searchProducts,
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          context.read<InventoryBloc>().add(LoadProducts(
                            searchQuery: null,
                            category: state.category,
                            stockFilter: state.stockFilter,
                            sortBy: state.sortBy,
                          ));
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildFilterButton(Icons.sort, () => _showSortBottomSheet(context, state)),
        ],
      ),
    );
  }

  Widget _buildFilterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, InventoryLoaded state) {
    final l10n = context.l10n;
    final stockFilterDisplay = {
      null: l10n.allStock,
      'in_stock': l10n.inStock,
      'low': l10n.lowStock,
      'out': l10n.outOfStock,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          // Category Filter
          Expanded(
            child: PopupMenuButton<String>(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == '__manage__') {
                  // Navigate to category management page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageCategoryScreen()),
                  );
                } else {
                  context.read<InventoryBloc>().add(LoadProducts(
                    searchQuery: state.searchQuery,
                    category: value == 'All' ? null : value,
                    stockFilter: state.stockFilter,
                    sortBy: state.sortBy,
                  ));
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                final cs = Theme.of(context).colorScheme;
                // Add "All" option
                items.add(PopupMenuItem(
                  value: 'All',
                  child: Text(context.l10n.allCategories, style: TextStyle(fontSize: 14, color: cs.onSurface)),
                ));
                // Add existing categories
                for (final cat in state.allCategories) {
                  if (cat != 'All') {
                    items.add(PopupMenuItem(
                      value: cat,
                      child: Text(cat, style: TextStyle(fontSize: 14, color: cs.onSurface)),
                    ));
                  }
                }
                if (state.allCategories.length > 1) {
                  items.add(const PopupMenuDivider());
                }
                items.add(PopupMenuItem(
                  value: '__manage__',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(context.l10n.manageCategories, style: TextStyle(fontSize: 14, color: cs.primary)),
                    ],
                  ),
                ));
                return items;
              },
              child: Builder(
                builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      // color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            state.category ?? context.l10n.allCategories,
                            style: TextStyle(fontSize: 14, color: cs.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: cs.primary),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Stock Filter
          Expanded(
            child: PopupMenuButton<String>(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                context.read<InventoryBloc>().add(LoadProducts(
                  searchQuery: state.searchQuery,
                  category: state.category,
                  stockFilter: value == '__all__' ? null : value,
                  sortBy: state.sortBy,
                ));
              },
              itemBuilder: (context) {
                final cs = Theme.of(context).colorScheme;
                return [
                  PopupMenuItem(value: '__all__', child: Text(context.l10n.allStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                  PopupMenuItem(value: 'in_stock', child: Text(context.l10n.inStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                  PopupMenuItem(value: 'low', child: Text(context.l10n.lowStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                  PopupMenuItem(value: 'out', child: Text(context.l10n.outOfStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                ];
              },
              child: Builder(
                builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      // color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            stockFilterDisplay[state.stockFilter] ?? context.l10n.allStock,
                            style: TextStyle(fontSize: 14, color: cs.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: cs.primary),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          // View Toggle Button
          _buildFilterButton(
            _isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined,
            () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<Product> products) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<InventoryBloc>().add(LoadProducts());
      },
      child: _isGridView
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) => _buildProductGridCard(context, products[index]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) => _buildProductCard(context, products[index]),
            ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final colorScheme = Theme.of(context).colorScheme;
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
                  // Product Image or Initial
                  product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(product.imagePath!),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          radius: 25,
                          child: Text(
                            product.name[0].toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (product.category != null && product.category!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.category!,
                                  style: TextStyle(fontSize: 11, color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.w500),
                                ),
                              ),
                            if (product.size != null && product.size!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.size!,
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
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
                  _buildInfoColumn(context.l10n.sellingPrice, '৳${context.l10n.formatAmount(product.sellingPrice)}', Colors.green),
                  _buildInfoColumn(context.l10n.purchasePrice, '৳${context.l10n.formatAmount(product.purchasePrice)}', Colors.blue),
                  _buildInfoColumn(context.l10n.quantity, '${context.l10n.formatDigits(product.currentStock.toString())} ${product.unit}', stockColor),
                ],
              ),
              if (_hasVariantChips(product)) ...[
                const SizedBox(height: 10),
                _buildVariantChips(context, product, colorScheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasVariantChips(Product product) {
    final variants = product.variants;
    if (variants == null || variants.isEmpty) return false;
    if (variants.length == 1 && (variants.first.label == null || variants.first.label!.isEmpty)) return false;
    return true;
  }

  Widget _buildVariantChips(BuildContext context, Product product, ColorScheme cs) {
    final variants = product.variants ?? [];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: variants.map((ProductVariant v) {
        final label = v.label ?? '';
        final chip = label.isNotEmpty
            ? '$label: ${v.currentStock} ${product.unit} · ৳${v.sellingPrice.toStringAsFixed(0)}'
            : '${v.currentStock} ${product.unit}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            chip,
            style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer, fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductGridCard(BuildContext context, Product product) {
    final colorScheme = Theme.of(context).colorScheme;
    final stockColor = product.currentStock <= 0
        ? Colors.red
        : product.currentStock <= product.minStockAlert
            ? Colors.orange
            : Colors.green;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAddEditProductDialog(context, product: product),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image / Avatar
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.imagePath != null &&
                        product.imagePath!.isNotEmpty &&
                        File(product.imagePath!).existsSync()
                    ? Image.file(File(product.imagePath!), fit: BoxFit.cover)
                    : Container(
                        color: colorScheme.primaryContainer,
                        alignment: Alignment.center,
                        child: Text(
                          product.name[0].toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                          ),
                        ),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '৳${context.l10n.formatAmount(product.sellingPrice)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: stockColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.l10n.formatDigits(product.currentStock.toString()),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: stockColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (product.category != null && product.category!.isNotEmpty || product.size != null && product.size!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (product.category != null && product.category!.isNotEmpty)
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(4)),
                              child: Text(product.category!, style: TextStyle(fontSize: 10, color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        if (product.size != null && product.size!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                            child: Text(product.size!, style: TextStyle(fontSize: 10, color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
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

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            context.l10n.noProductsFound,
            style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.addProductHint,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showSortBottomSheet(BuildContext context, InventoryLoaded state) {
    final l10n = context.l10n;
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
              Text(
                l10n.sortLabel,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSortOption(context, state, 'latest', l10n.sortLatest, Icons.access_time),
              _buildSortOption(context, state, 'quantity_high', l10n.sortQuantityHighToLow, Icons.arrow_downward),
              _buildSortOption(context, state, 'quantity_low', l10n.sortQuantityLowToHigh, Icons.arrow_upward),
              _buildSortOption(context, state, 'name_asc', l10n.sortNameAZ, Icons.sort_by_alpha),
              _buildSortOption(context, state, 'name_desc', l10n.sortNameZA, Icons.sort_by_alpha),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(BuildContext context, InventoryLoaded state, String sortValue, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = state.sortBy == sortValue;
    return ListTile(
      leading: Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: colorScheme.primary) : null,
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
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductFormSheet(product: product, parentMessenger: messenger),
    );
  }
}
