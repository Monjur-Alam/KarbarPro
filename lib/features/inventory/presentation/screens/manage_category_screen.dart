import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/l10n/app_localizations.dart';

class ManageCategoryScreen extends StatefulWidget {
  const ManageCategoryScreen({super.key});

  @override
  State<ManageCategoryScreen> createState() => _ManageCategoryScreenState();
}

class _ManageCategoryScreenState extends State<ManageCategoryScreen> {
  List<Map<String, dynamic>> _categories = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final db = context.read<DatabaseHelper>();
    final database = await db.database;

    // Get unique categories with product count
    final result = await database.rawQuery('''
      SELECT 
        ${DatabaseConstants.colCategory} as category,
        COUNT(*) as product_count
      FROM ${DatabaseConstants.tableProducts}
      WHERE ${DatabaseConstants.colCategory} IS NOT NULL 
        AND ${DatabaseConstants.colCategory} != ''
      GROUP BY ${DatabaseConstants.colCategory}
      ORDER BY ${DatabaseConstants.colCategory} ASC
    ''');

    setState(() {
      _categories = result;
      _isLoading = false;
    });
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('নতুন ক্যাটাগরি যোগ করুন'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ক্যাটাগরির নাম *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Check if category already exists
      final exists = _categories.any((cat) => 
        cat['category'].toString().toLowerCase() == result.toLowerCase()
      );

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('এই ক্যাটাগরি ইতিমধ্যে বিদ্যমান'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Category will be created when a product is added with this category
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ক্যাটাগরি "$result" তৈরি হবে যখন কোনো পণ্য এই ক্যাটাগরিতে যুক্ত হবে'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditCategoryDialog(String oldCategory) async {
    final controller = TextEditingController(text: oldCategory);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('ক্যাটাগরি সম্পাদনা করুন'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ক্যাটাগরির নাম *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != oldCategory) {
      final db = context.read<DatabaseHelper>();
      final database = await db.database;

      await database.update(
        DatabaseConstants.tableProducts,
        {DatabaseConstants.colCategory: result},
        where: '${DatabaseConstants.colCategory} = ?',
        whereArgs: [oldCategory],
      );

      _loadCategories();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ক্যাটাগরি আপডেট হয়েছে'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(String category, int productCount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('ক্যাটাগরি মুছে ফেলুন'),
        content: Text(
          'আপনি কি নিশ্চিত যে "$category" ক্যাটাগরি মুছে ফেলতে চান?\n\n'
          'এই ক্যাটাগরিতে $productCount টি পণ্য আছে। পণ্যগুলি মুছে যাবে না, শুধুমাত্র তাদের ক্যাটাগরি খালি হয়ে যাবে।'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = context.read<DatabaseHelper>();
      final database = await db.database;

      // Set category to null for all products in this category
      await database.update(
        DatabaseConstants.tableProducts,
        {DatabaseConstants.colCategory: null},
        where: '${DatabaseConstants.colCategory} = ?',
        whereArgs: [category],
      );

      _loadCategories();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ক্যাটাগরি মুছে ফেলা হয়েছে'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((cat) {
      final query = _searchController.text.toLowerCase();
      return cat['category'].toString().toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'পণ্যের ক্যাটাগরি ম্যানেজ করুন',
          style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'পণ্য ক্যাটাগরি অনুসন্ধান করুন...',
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
          
          // Category List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'কোনো ক্যাটাগরি পাওয়া যায়নি',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = filteredCategories[index];
                          final categoryName = category['category'].toString();
                          final productCount = category['product_count'] as int;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                categoryName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                '${context.l10n.formatDigits(productCount.toString())} আইটেম',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () => _showEditCategoryDialog(categoryName),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteCategory(categoryName, productCount),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('নতুন ক্যাটাগরি যোগ'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
}
