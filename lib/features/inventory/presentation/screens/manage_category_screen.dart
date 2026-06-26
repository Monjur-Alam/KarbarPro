import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
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

    // All categories from product_categories table + product count (even if 0)
    final result = await database.rawQuery('''
      SELECT
        pc.${DatabaseConstants.colName} as category,
        COUNT(p.${DatabaseConstants.colId}) as product_count
      FROM ${DatabaseConstants.tableProductCategories} pc
      LEFT JOIN ${DatabaseConstants.tableProducts} p
        ON p.${DatabaseConstants.colCategory} = pc.${DatabaseConstants.colName}
      GROUP BY pc.${DatabaseConstants.colName}
      ORDER BY pc.${DatabaseConstants.colName} ASC
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
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('নতুন ক্যাটাগরি যোগ করুন', style: TextStyle(color: colorScheme.onSurface)),
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
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('যোগ করুন'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final exists = _categories.any(
        (cat) => cat['category'].toString().toLowerCase() == result.toLowerCase(),
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
        final db = context.read<DatabaseHelper>();
        final database = await db.database;
        final now = DateTime.now().toIso8601String();
        await database.insert(
          DatabaseConstants.tableProductCategories,
          {
            DatabaseConstants.colName: result,
            DatabaseConstants.colCreatedAt: now,
            DatabaseConstants.colUpdatedAt: now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ক্যাটাগরি "$result" যোগ হয়েছে'),
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
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('ক্যাটাগরি সম্পাদনা করুন', style: TextStyle(color: colorScheme.onSurface)),
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
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('সংরক্ষণ'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != oldCategory) {
      final db = context.read<DatabaseHelper>();
      final database = await db.database;
      final now = DateTime.now().toIso8601String();

      // Update the category name in product_categories table
      await database.update(
        DatabaseConstants.tableProductCategories,
        {DatabaseConstants.colName: result, DatabaseConstants.colUpdatedAt: now},
        where: '${DatabaseConstants.colName} = ?',
        whereArgs: [oldCategory],
      );

      // Update all products that have the old category
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
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('ক্যাটাগরি মুছে ফেলুন', style: TextStyle(color: colorScheme.onSurface)),
          content: Text(
            productCount > 0
                ? 'আপনি কি নিশ্চিত যে "$category" ক্যাটাগরি মুছে ফেলতে চান?\n\n'
                    'এই ক্যাটাগরিতে $productCount টি পণ্য আছে। পণ্যগুলি মুছে যাবে না, শুধুমাত্র তাদের ক্যাটাগরি খালি হয়ে যাবে।'
                : 'আপনি কি নিশ্চিত যে "$category" ক্যাটাগরি মুছে ফেলতে চান?',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
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
        );
      },
    );

    if (confirm == true) {
      final db = context.read<DatabaseHelper>();
      final database = await db.database;

      // Remove from product_categories table
      await database.delete(
        DatabaseConstants.tableProductCategories,
        where: '${DatabaseConstants.colName} = ?',
        whereArgs: [category],
      );

      // Clear category from all products
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
    final colorScheme = Theme.of(context).colorScheme;
    final filteredCategories = _categories.where((cat) {
      final query = _searchController.text.toLowerCase();
      return cat['category'].toString().toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: Text(
          'পণ্যের ক্যাটাগরি ম্যানেজ করুন',
          style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18, color: colorScheme.onSurface),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.surface,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'পণ্য ক্যাটাগরি অনুসন্ধান করুন...',
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
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

          // Category List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 80, color: colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              'কোনো ক্যাটাগরি পাওয়া যায়নি',
                              style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
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
                            color: colorScheme.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                categoryName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
                              ),
                              subtitle: Text(
                                '${context.l10n.formatDigits(productCount.toString())} আইটেম',
                                style: TextStyle(
                                  color: productCount == 0 ? colorScheme.outlineVariant : colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
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
