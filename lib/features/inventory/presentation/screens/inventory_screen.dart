import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/product.dart';
import 'manage_category_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/settings/app_settings_cubit.dart';

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
            ],
          ),
        ),
      ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductFormBottomSheet(product: product),
    );
  }
}

class ProductFormBottomSheet extends StatefulWidget {
  final Product? product;

  const ProductFormBottomSheet({super.key, this.product});

  @override
  State<ProductFormBottomSheet> createState() => _ProductFormBottomSheetState();
}

class _ProductFormBottomSheetState extends State<ProductFormBottomSheet> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  List<String> _existingCategories = [];
  final _stockController = TextEditingController();
  final _unitController = TextEditingController();
  final _sizeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _itemCodeController = TextEditingController();

  final _nameFocus = FocusNode();
  final _stockFocus = FocusNode();
  final _unitFocus = FocusNode();
  final _sizeFocus = FocusNode();
  final _sellingPriceFocus = FocusNode();
  final _purchasePriceFocus = FocusNode();
  final _itemCodeFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool get _isFormValid {
    final name = _nameController.text.trim();
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;
    return name.isNotEmpty && sellingPrice > 0;
  }

  @override
  void initState() {
    super.initState();
    _loadExistingCategories();

    _nameController.addListener(() => setState(() {}));
    _sellingPriceController.addListener(() => setState(() {}));

    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _categoryController.text = widget.product!.category ?? '';
      _sellingPriceController.text = widget.product!.sellingPrice.toString();
      _purchasePriceController.text = widget.product!.purchasePrice.toString();
      _stockController.text = widget.product!.currentStock.toString();
      _unitController.text = widget.product!.unit;
      _sizeController.text = widget.product!.size ?? '';
      _itemCodeController.text = widget.product!.barcode ?? _generateItemCode();
      if (widget.product!.imagePath != null && widget.product!.imagePath!.isNotEmpty) {
        _selectedImage = File(widget.product!.imagePath!);
      }
    } else {
      _unitController.text = 'pcs';
      _itemCodeController.text = _generateItemCode();
    }
  }

  Future<void> _loadExistingCategories() async {
    final db = context.read<DatabaseHelper>();
    final database = await db.database;

    final result = await database.rawQuery('''
      SELECT ${DatabaseConstants.colName}
      FROM ${DatabaseConstants.tableProductCategories}
      ORDER BY ${DatabaseConstants.colName} ASC
    ''');

    setState(() {
      _existingCategories = result
          .map((row) => row[DatabaseConstants.colName] as String)
          .toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _sizeController.dispose();
    _descriptionController.dispose();
    _itemCodeController.dispose();
    _nameFocus.dispose();
    _stockFocus.dispose();
    _unitFocus.dispose();
    _sizeFocus.dispose();
    _sellingPriceFocus.dispose();
    _purchasePriceFocus.dispose();
    _itemCodeFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    // Check camera permission
    final status = await Permission.camera.request();

    if (status.isGranted) {
      // Permission granted, show image source options
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: colorScheme.primary),
                title: Text(l10n.camera),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: colorScheme.tertiary),
                title: Text(l10n.gallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await _picker.pickImage(source: source);
        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });
        }
      }
    } else if (status.isDenied) {
      // Permission denied, ask again
      await Permission.camera.request();
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied, navigate to settings
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.permissionRequired),
            content: Text(l10n.cameraPermissionMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.openSettings),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
    }
  }

  String _generateItemCode() {
    return 'P${DateTime.now().millisecondsSinceEpoch}';
  }

  void _saveProduct() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final name = _nameController.text.trim();
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    final unit = _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim();
    final category = _categoryController.text.trim();
    final size = _sizeController.text.trim();
    final itemCode = _itemCodeController.text.trim();
    final imagePath = _selectedImage?.path;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterItemName), backgroundColor: colorScheme.error),
      );
      return;
    }

    if (sellingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterSellingPrice), backgroundColor: colorScheme.error),
      );
      return;
    }

    final newProduct = Product(
      id: widget.product?.id,
      name: name,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      currentStock: stock,
      unit: unit,
      size: size.isEmpty ? null : size,
      category: category.isEmpty ? null : category,
      barcode: itemCode.isEmpty ? null : itemCode,
      imagePath: imagePath,
      minStockAlert: 5,
      createdAt: widget.product?.createdAt,
      updatedAt: DateTime.now(),
    );

    if (widget.product == null) {
      context.read<InventoryBloc>().add(AddProduct(newProduct));
    } else {
      context.read<InventoryBloc>().add(UpdateProduct(newProduct));
    }
    Navigator.pop(context);
  }

  Future<void> _scanBarcode() async {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    // Check current status first to avoid unnecessary dialog
    var status = await Permission.camera.status;

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showCameraPermissionDeniedDialog(l10n, colorScheme);
      return;
    }

    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (!mounted) return;

    if (status.isGranted) {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
      );
      if (result != null && result.isNotEmpty && mounted) {
        setState(() => _itemCodeController.text = result);
      }
    } else if (status.isPermanentlyDenied) {
      _showCameraPermissionDeniedDialog(l10n, colorScheme);
    } else {
      // Denied (not permanent) — show a brief message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cameraPermissionMessage),
          backgroundColor: colorScheme.error,
          action: SnackBarAction(
            label: l10n.openSettings,
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  void _showCameraPermissionDeniedDialog(AppLocalizations l10n, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.camera_alt_outlined, color: colorScheme.error),
            const SizedBox(width: 8),
            Text(l10n.permissionRequired),
          ],
        ),
        content: Text(l10n.cameraPermissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }

  void _showBarcodePrintDialog() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final itemCode = _itemCodeController.text.trim();

    if (itemCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.itemCodeHint), backgroundColor: colorScheme.error),
      );
      return;
    }

    final defaultQty = (int.tryParse(_stockController.text) ?? 1).clamp(1, 9999);
    int qty = defaultQty;
    int selectedSizeIdx = 1; // default 50×30mm

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final scheme = Theme.of(ctx).colorScheme;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(Icons.print, color: Colors.deepPurple, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        l10n.printBarcode,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quantity row
                  Text(
                    l10n.quantity,
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // minus
                        IconButton(
                          icon: Icon(Icons.remove, color: qty <= 1 ? scheme.outlineVariant : scheme.error),
                          onPressed: qty <= 1 ? null : () => setDialogState(() => qty--),
                        ),
                        Expanded(
                          child: Text(
                            qty.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // plus
                        IconButton(
                          icon: Icon(Icons.add, color: scheme.primary),
                          onPressed: qty >= 9999 ? null : () => setDialogState(() => qty++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Default: ${l10n.initialStock} ($defaultQty)',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),

                  const SizedBox(height: 20),

                  // Label size selector
                  Text(
                    'স্টিকার সাইজ',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: List.generate(_stickerSizes.length, (i) {
                      final s = _stickerSizes[i];
                      final isSelected = i == selectedSizeIdx;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedSizeIdx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.deepPurple : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? Colors.deepPurple : scheme.outlineVariant,
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : scheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _printBarcodes(
                              labelCount: qty,
                              stickerSize: _stickerSizes[selectedSizeIdx],
                            );
                          },
                          icon: const Icon(Icons.print, size: 18),
                          label: Text(l10n.printBarcode),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _printBarcodes({required int labelCount, required _StickerSize stickerSize}) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final barcodeTitle = l10n.barcodePreview;

    final name = _nameController.text.trim();
    final itemCode = _itemCodeController.text.trim();
    final price = _sellingPriceController.text.trim();
    final size = _sizeController.text.trim();

    // Show loading while generating PDF
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfBytes = await _generateBarcodePdf(
        name: name,
        itemCode: itemCode,
        price: price,
        size: size,
        labelCount: labelCount,
        stickerSize: stickerSize,
      );

      if (!mounted) return;
      navigator.pop(); // close loading dialog

      await navigator.push(
        MaterialPageRoute(
          builder: (_) => _BarcodePrintPreviewPage(
            pdfBytes: pdfBytes,
            title: barcodeTitle,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // close loading dialog
      messenger.showSnackBar(
        SnackBar(content: Text('Barcode error: $e'), backgroundColor: colorScheme.error),
      );
    }
  }

  Future<Uint8List> _generateBarcodePdf({
    required String name,
    required String itemCode,
    required String price,
    required String size,
    required int labelCount,
    required _StickerSize stickerSize,
  }) async {
    // Load Bengali-supporting font from app assets
    final regularData = await rootBundle.load('assets/fonts/HindSiliguri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/HindSiliguri-Bold.ttf');
    final font = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    // Page = exact sticker size, 1 label per page (sticker printer format)
    final labelWpt = stickerSize.w * PdfPageFormat.mm;
    final labelHpt = stickerSize.h * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(labelWpt, labelHpt, marginAll: 1.5 * PdfPageFormat.mm);

    // Scale font sizes proportional to label height
    final scale = (stickerSize.h / 30.0).clamp(0.7, 2.0);
    final nameFontSize = (7.5 * scale).clamp(5.0, 14.0);
    final sizeFontSize = (6.5 * scale).clamp(4.5, 12.0);
    final priceFontSize = (9.0 * scale).clamp(6.0, 16.0);
    final codeFontSize = (5.0 * scale).clamp(3.5, 9.0);
    final barcodeH = (stickerSize.h * 0.38) * PdfPageFormat.mm;

    final displayName = name.isEmpty ? '-' : name;

    final pdf = pw.Document();

    for (int i = 0; i < labelCount; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (ctx) => pw.Container(
            width: double.infinity,
            height: double.infinity,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Product name
                pw.Text(
                  displayName,
                  style: pw.TextStyle(font: boldFont, fontSize: nameFontSize),
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                ),
                // Size (if set)
                if (size.isNotEmpty)
                  pw.Text(
                    'Size: $size',
                    style: pw.TextStyle(font: font, fontSize: sizeFontSize),
                    textAlign: pw.TextAlign.center,
                  ),
                // Price (bold, prominent)
                pw.Text(
                  'Tk $price',
                  style: pw.TextStyle(font: boldFont, fontSize: priceFontSize),
                  textAlign: pw.TextAlign.center,
                ),
                // Barcode
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: itemCode,
                  height: barcodeH,
                  width: labelWpt - (3 * PdfPageFormat.mm),
                  drawText: false,
                ),
                // Item code text
                pw.Text(
                  itemCode,
                  style: pw.TextStyle(font: font, fontSize: codeFontSize),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return await pdf.save();
  }

  void _showInstructions() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  l10n.addProductInstructionsTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInstructionItem(l10n.formatDigits('1'), l10n.instruction1),
            _buildInstructionItem(l10n.formatDigits('2'), l10n.instruction2),
            _buildInstructionItem(l10n.formatDigits('3'), l10n.instruction3),
            _buildInstructionItem(l10n.formatDigits('4'), l10n.instruction4),
            _buildInstructionItem(l10n.formatDigits('5'), l10n.instruction5),
            _buildInstructionItem(l10n.formatDigits('6'), l10n.instruction6),
            _buildInstructionItem(l10n.formatDigits('7'), l10n.instruction7),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.gotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.product == null ? l10n.addNewItem : l10n.editItem,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: _showInstructions,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Product Name
                      Text(l10n.itemNameRequired, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _stockFocus.requestFocus(),
                        decoration: InputDecoration(
                          hintText: l10n.itemNameHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category
                      Text(l10n.categoryLabel, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final result = await showModalBottomSheet<String>(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.selectCategory,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_existingCategories.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                        child: Text(l10n.noCategoriesHint),
                                      ),
                                    )
                                  else
                                    ..._existingCategories.map((cat) => ListTile(
                                      title: Text(cat),
                                      onTap: () => Navigator.pop(context, cat),
                                    )),
                                  const Divider(),
                                  ListTile(
                                    leading: Icon(Icons.add, color: colorScheme.primary),
                                    title: Text(l10n.addNewCategory),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final newCat = await showDialog<String>(
                                        context: context,
                                        builder: (context) {
                                          final controller = TextEditingController();
                                          return AlertDialog(
                                            title: Text(l10n.newCategory),
                                            content: TextField(
                                              controller: controller,
                                              autofocus: true,
                                              decoration: InputDecoration(
                                                hintText: l10n.categoryHint,
                                                border: const OutlineInputBorder(),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(l10n.cancel),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, controller.text),
                                                child: Text(l10n.addLabel),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (newCat != null && newCat.isNotEmpty) {
                                        setState(() => _categoryController.text = newCat);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() => _categoryController.text = result);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _categoryController.text.isEmpty ? l10n.selectCategory : _categoryController.text,
                                style: TextStyle(
                                  color: _categoryController.text.isEmpty ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stock and Unit
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.initialStock, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _stockController,
                                  focusNode: _stockFocus,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => _unitFocus.requestFocus(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '০',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.unit, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _unitController,
                                  focusNode: _unitFocus,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => _sizeFocus.requestFocus(),
                                  decoration: InputDecoration(
                                    hintText: 'pcs',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Size
                      Text(l10n.productSize, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sizeController,
                        focusNode: _sizeFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _sellingPriceFocus.requestFocus(),
                        decoration: InputDecoration(
                          hintText: l10n.sizeHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Prices
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.sellingPriceRequired, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _sellingPriceController,
                                  focusNode: _sellingPriceFocus,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => _purchasePriceFocus.requestFocus(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '০',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.purchasePriceLabel, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _purchasePriceController,
                                  focusNode: _purchasePriceFocus,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => _itemCodeFocus.requestFocus(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '০',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Item Code
                      Text(l10n.itemCode, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _itemCodeController,
                        focusNode: _itemCodeFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _descriptionFocus.requestFocus(),
                        decoration: InputDecoration(
                          hintText: l10n.itemCodeHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.qr_code_scanner, size: 20, color: colorScheme.primary),
                                tooltip: 'Scan barcode',
                                onPressed: _scanBarcode,
                              ),
                              IconButton(
                                icon: Icon(Icons.refresh, size: 20, color: colorScheme.primary),
                                tooltip: 'Regenerate',
                                onPressed: () => setState(() => _itemCodeController.text = _generateItemCode()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(l10n.description, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocus,
                        textInputAction: TextInputAction.done,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: l10n.descriptionHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Image Upload
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _selectedImage == null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined, size: 40, color: colorScheme.outlineVariant),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.addItemImage,
                                        style: TextStyle(color: colorScheme.primary, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showBarcodePrintDialog,
                          icon: const Icon(Icons.barcode_reader, size: 18),
                          label: Text(l10n.printBarcode, style: const TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: Colors.deepPurple,
                            side: const BorderSide(color: Colors.deepPurple),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isFormValid ? _saveProduct : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: Text(l10n.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Barcode Scanner Page ────────────────────────────────────────────────────

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _hasResult = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasResult) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null && code.isNotEmpty) {
      _hasResult = true;
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('বারকোড স্ক্যান'),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scan overlay
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Scan frame
                Container(
                  width: 260,
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 2.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Corner accents
                      for (final alignment in [
                        Alignment.topLeft,
                        Alignment.topRight,
                        Alignment.bottomLeft,
                        Alignment.bottomRight,
                      ])
                        Align(
                          alignment: alignment,
                          child: _CornerAccent(alignment: alignment, color: colorScheme.primary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ক্যামেরা বারকোডের উপর ধরুন',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerAccent extends StatelessWidget {
  final Alignment alignment;
  final Color color;

  const _CornerAccent({required this.alignment, required this.color});

  @override
  Widget build(BuildContext context) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    const size = 20.0;
    const thickness = 3.0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          isTop: isTop,
          isLeft: isLeft,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool isTop;
  final bool isLeft;
  final double thickness;

  const _CornerPainter({
    required this.color,
    required this.isTop,
    required this.isLeft,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final ex = isLeft ? size.width : 0.0;
    final ey = isTop ? size.height : 0.0;

    canvas.drawLine(Offset(x, y), Offset(ex, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, ey), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Sticker Size Model ──────────────────────────────────────────────────────

class _StickerSize {
  final String label;
  final double w; // mm
  final double h; // mm
  const _StickerSize(this.label, this.w, this.h);
}

const _stickerSizes = [
  _StickerSize('38×25mm', 38, 25),
  _StickerSize('50×30mm', 50, 30),
  _StickerSize('57×32mm', 57, 32),
  _StickerSize('60×40mm', 60, 40),
  _StickerSize('80×50mm', 80, 50),
];

// ─── Barcode Print Preview Page ─────────────────────────────────────────────

class _BarcodePrintPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const _BarcodePrintPreviewPage({
    required this.pdfBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: PdfPreview(
            build: (_) async => pdfBytes,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canDebug: false,
            scrollViewDecoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerLow
                  : Colors.grey.shade300,
            ),
            pdfPreviewPageDecoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black45 : Colors.black26,
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            loadingWidget: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading preview...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
