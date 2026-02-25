import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/product.dart';
import 'manage_category_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surface,
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
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
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
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
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
            child: PopupMenuButton<String?>(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                context.read<InventoryBloc>().add(LoadProducts(
                  searchQuery: state.searchQuery,
                  category: state.category,
                  stockFilter: value,
                  sortBy: state.sortBy,
                ));
              },
              itemBuilder: (context) {
                final cs = Theme.of(context).colorScheme;
                return [
                  PopupMenuItem(value: null, child: Text(context.l10n.allStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                  PopupMenuItem(value: 'in_stock', child: Text(context.l10n.inStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                  PopupMenuItem(value: 'low', child: Text(context.l10n.lowStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                  PopupMenuItem(value: 'out', child: Text(context.l10n.outOfStock, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                ];
              },
              child: Builder(
                builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
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
        ],
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<Product> products) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<InventoryBloc>().add(LoadProducts());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(context, product);
        },
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
                        if (product.category != null && product.category!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.category!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onTertiaryContainer,
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
  final _descriptionController = TextEditingController();
  final _itemCodeController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingCategories();

    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _categoryController.text = widget.product!.category ?? '';
      _sellingPriceController.text = widget.product!.sellingPrice.toString();
      _purchasePriceController.text = widget.product!.purchasePrice.toString();
      _stockController.text = widget.product!.currentStock.toString();
      _unitController.text = widget.product!.unit;
      _itemCodeController.text = widget.product!.barcode ?? '';
      if (widget.product!.imagePath != null && widget.product!.imagePath!.isNotEmpty) {
        _selectedImage = File(widget.product!.imagePath!);
      }
    } else {
      _unitController.text = 'pcs';
    }
  }

  Future<void> _loadExistingCategories() async {
    final db = context.read<DatabaseHelper>();
    final database = await db.database;

    final result = await database.rawQuery('''
      SELECT DISTINCT ${DatabaseConstants.colCategory}
      FROM ${DatabaseConstants.tableProducts}
      WHERE ${DatabaseConstants.colCategory} IS NOT NULL
        AND ${DatabaseConstants.colCategory} != ''
      ORDER BY ${DatabaseConstants.colCategory} ASC
    ''');

    setState(() {
      _existingCategories = result
          .map((row) => row[DatabaseConstants.colCategory] as String)
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
    _descriptionController.dispose();
    _itemCodeController.dispose();
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

  void _saveProduct() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final name = _nameController.text.trim();
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    final unit = _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim();
    final category = _categoryController.text.trim();
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
            _buildInstructionItem('১', l10n.instruction1),
            _buildInstructionItem('২', l10n.instruction2),
            _buildInstructionItem('৩', l10n.instruction3),
            _buildInstructionItem('৪', l10n.instruction4),
            _buildInstructionItem('৫', l10n.instruction5),
            _buildInstructionItem('৬', l10n.instruction6),
            _buildInstructionItem('৭', l10n.instruction7),
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
            child: Row(
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
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(l10n.itemNameRequired, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
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
                    decoration: InputDecoration(
                      hintText: l10n.itemCodeHint,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(l10n.description, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
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
                ],
              ),
            ),
          ),

          // Save Button
          Container(
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(l10n.save, style: const TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
