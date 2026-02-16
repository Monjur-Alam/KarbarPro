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
    // Map internal values to Bengali display names
    final stockFilterDisplay = {
      null: 'সমস্ত স্টক',
      'in_stock': 'স্টক আছে',
      'low': 'কম স্টক',
      'out': 'স্টক শেষ',
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
                
                // Add "All" option
                items.add(PopupMenuItem(
                  value: 'All',
                  child: Text('সব ক্যাটাগরি', style: const TextStyle(fontSize: 14)),
                ));
                
                // Add existing categories
                for (final cat in state.allCategories) {
                  if (cat != 'All') {
                    items.add(PopupMenuItem(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 14)),
                    ));
                  }
                }
                
                // Add divider and manage option
                if (state.allCategories.length > 1) {
                  items.add(const PopupMenuDivider());
                }
                items.add(PopupMenuItem(
                  value: '__manage__',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text('ক্যাটাগরি ম্যানেজ করুন', 
                        style: TextStyle(fontSize: 14, color: Colors.blue.shade700)),
                    ],
                  ),
                ));
                
                return items;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        state.category ?? 'সব ক্যাটাগরি',
                        style: const TextStyle(fontSize: 14, color: Colors.teal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.teal),
                  ],
                ),
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
              itemBuilder: (context) => [
                PopupMenuItem(value: null, child: Text('সমস্ত স্টক', style: const TextStyle(fontSize: 14))),
                PopupMenuItem(value: 'in_stock', child: Text('স্টক আছে', style: const TextStyle(fontSize: 14))),
                PopupMenuItem(value: 'low', child: Text('কম স্টক', style: const TextStyle(fontSize: 14))),
                PopupMenuItem(value: 'out', child: Text('স্টক শেষ', style: const TextStyle(fontSize: 14))),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        stockFilterDisplay[state.stockFilter] ?? 'সমস্ত স্টক',
                        style: const TextStyle(fontSize: 14, color: Colors.teal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.teal),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                          backgroundColor: Colors.blue.shade50,
                          radius: 25,
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
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('ক্যামেরা'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('গ্যালারি'),
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
            title: const Text('অনুমতি প্রয়োজন'),
            content: const Text(
              'ছবি তুলতে ক্যামেরা অনুমতি প্রয়োজন। সেটিংস থেকে অনুমতি দিন।'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('বাতিল'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('সেটিংস খুলুন'),
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
        const SnackBar(content: Text('আইটেমের নাম লিখুন'), backgroundColor: Colors.red),
      );
      return;
    }

    if (sellingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বিক্রয় মূল্য লিখুন'), backgroundColor: Colors.red),
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
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'পণ্য যোগ করার নির্দেশনা',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInstructionItem('১', 'আইটেমের নাম লিখুন (বাধ্যতামূলক)'),
            _buildInstructionItem('২', 'ক্যাটাগরি নির্বাচন করুন (ঐচ্ছিক)'),
            _buildInstructionItem('৩', 'বিক্রয় মূল্য এবং ক্রয় মূল্য লিখুন'),
            _buildInstructionItem('৪', 'প্রাথমিক স্টক পরিমাণ এবং একক লিখুন'),
            _buildInstructionItem('৫', 'প্রয়োজনে আইটেম কোড এবং বিবরণ যোগ করুন'),
            _buildInstructionItem('৬', 'ছবি যোগ করতে ক্যামেরা আইকনে ক্লিক করুন'),
            _buildInstructionItem('৭', 'সব তথ্য পূরণ করে "সেভ করুন" বাটনে ক্লিক করুন'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('বুঝেছি'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.blue.shade700,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
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
                    widget.product == null ? 'নতুন আইটেম যোগ' : 'আইটেম সম্পাদনা',
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
                  const Text('আইটেমের নাম *', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'আইটেমের নাম লিখুন',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Category
                  const Text('শ্রেণী', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                              const Text(
                                'ক্যাটাগরি নির্বাচন করুন',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              if (_existingCategories.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text('কোনো ক্যাটাগরি নেই। নতুন ক্যাটাগরি লিখুন।'),
                                  ),
                                )
                              else
                                ..._existingCategories.map((cat) => ListTile(
                                  title: Text(cat),
                                  onTap: () => Navigator.pop(context, cat),
                                )),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.add, color: Colors.blue),
                                title: const Text('নতুন ক্যাটাগরি যোগ করুন'),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final newCat = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      final controller = TextEditingController();
                                      return AlertDialog(
                                        title: const Text('নতুন ক্যাটাগরি'),
                                        content: TextField(
                                          controller: controller,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            hintText: 'ক্যাটাগরি লিখুন',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('বাতিল'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, controller.text),
                                            child: const Text('যোগ করুন'),
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
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _categoryController.text.isEmpty ? 'ক্যাটাগরি নির্বাচন করুন' : _categoryController.text,
                            style: TextStyle(
                              color: _categoryController.text.isEmpty ? Colors.grey : Colors.black,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
                            const Text('প্রাথমিক স্টক', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                            const Text('একক', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                            const Text('বিক্রয় মূল্য *', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                            const Text('ক্রয় মূল্য', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                  const Text('আইটেম কোড', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _itemCodeController,
                    decoration: InputDecoration(
                      hintText: 'আইটেম কোড লিখুন',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  const Text('বিবরণ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'বিবরণ লিখুন',
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
                        border: Border.all(color: Colors.grey.shade300),
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
                                  Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'আইটেমের ছবি যোগ করুন',
                                    style: TextStyle(color: Colors.teal.shade700, fontSize: 14),
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
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
                child: const Text('সেভ করুন', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
