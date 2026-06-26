import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';

class ManageAttributeScreen extends StatefulWidget {
  final String title;
  final String tableName;
  final String addLabel;
  final String fieldLabel;

  const ManageAttributeScreen({
    super.key,
    required this.title,
    required this.tableName,
    required this.addLabel,
    required this.fieldLabel,
  });

  @override
  State<ManageAttributeScreen> createState() => _ManageAttributeScreenState();
}

class _ManageAttributeScreenState extends State<ManageAttributeScreen> {
  List<Map<String, dynamic>> _items = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final dbHelper = context.read<DatabaseHelper>();
    final database = await dbHelper.database;
    final result = await database.query(
      widget.tableName,
      orderBy: '${DatabaseConstants.colName} ASC',
    );
    setState(() {
      _items = result;
      _isLoading = false;
    });
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    final result = await _showInputDialog(
      title: widget.addLabel,
      controller: controller,
      confirmLabel: 'যোগ করুন',
    );
    if (result == null || result.isEmpty) return;

    final exists = _items.any(
      (item) => item[DatabaseConstants.colName].toString().toLowerCase() == result.toLowerCase(),
    );
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$result" ইতিমধ্যে বিদ্যমান'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final dbHelper = context.read<DatabaseHelper>();
    final database = await dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await database.insert(
      widget.tableName,
      {DatabaseConstants.colName: result, DatabaseConstants.colCreatedAt: now, DatabaseConstants.colUpdatedAt: now},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _loadItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$result" যোগ হয়েছে'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final id = item[DatabaseConstants.colId] as int;
    final oldName = item[DatabaseConstants.colName].toString();
    final controller = TextEditingController(text: oldName);

    final result = await _showInputDialog(
      title: 'সম্পাদনা করুন',
      controller: controller,
      confirmLabel: 'সংরক্ষণ',
    );
    if (result == null || result.isEmpty || result == oldName) return;

    final dbHelper = context.read<DatabaseHelper>();
    final database = await dbHelper.database;
    await database.update(
      widget.tableName,
      {DatabaseConstants.colName: result, DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String()},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
    _loadItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('আপডেট হয়েছে'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item[DatabaseConstants.colId] as int;
    final name = item[DatabaseConstants.colName].toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('মুছে ফেলুন', style: TextStyle(color: cs.onSurface)),
          content: Text('"$name" মুছে ফেলতে চান?', style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('মুছুন'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final dbHelper = context.read<DatabaseHelper>();
    final database = await dbHelper.database;
    await database.delete(widget.tableName, where: '${DatabaseConstants.colId} = ?', whereArgs: [id]);
    _loadItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" মুছে ফেলা হয়েছে'), backgroundColor: Colors.green),
      );
    }
  }

  Future<String?> _showInputDialog({
    required String title,
    required TextEditingController controller,
    required String confirmLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: TextStyle(color: cs.onSurface)),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: widget.fieldLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) Navigator.pop(context, controller.text.trim());
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _items.where((item) {
      final q = _searchController.text.toLowerCase();
      return item[DatabaseConstants.colName].toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surface,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18, color: cs.onSurface),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: cs.surface,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'অনুসন্ধান করুন...',
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: cs.outlineVariant),
                            const SizedBox(height: 16),
                            Text('কোনো ডেটা পাওয়া যায়নি', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _x) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final name = item[DatabaseConstants.colName].toString();
                          return Card(
                            elevation: 1,
                            color: cs.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: cs.primary),
                                    onPressed: () => _showEditDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteItem(item),
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
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add, size: 20),
        label: Text(widget.addLabel),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
}
