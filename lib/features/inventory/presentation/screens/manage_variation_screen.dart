import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';

class ManageVariationScreen extends StatefulWidget {
  const ManageVariationScreen({super.key});

  @override
  State<ManageVariationScreen> createState() => _ManageVariationScreenState();
}

class _ManageVariationScreenState extends State<ManageVariationScreen> {
  List<_Variation> _variations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVariations();
  }

  Future<void> _loadVariations() async {
    setState(() => _isLoading = true);
    final dbHelper = context.read<DatabaseHelper>();
    final db = await dbHelper.database;

    final rows = await db.query(
      DatabaseConstants.tableProductVariations,
      orderBy: '${DatabaseConstants.colName} ASC',
    );

    final variations = <_Variation>[];
    for (final row in rows) {
      final id = row[DatabaseConstants.colId] as int;
      final name = row[DatabaseConstants.colName] as String;
      final valueRows = await db.query(
        DatabaseConstants.tableProductVariationValues,
        where: '${DatabaseConstants.colVariationId} = ?',
        whereArgs: [id],
        orderBy: '${DatabaseConstants.colId} ASC',
      );
      final values = valueRows.map((v) => _VariationValue(
        id: v[DatabaseConstants.colId] as int,
        value: v['value'] as String,
      )).toList();
      variations.add(_Variation(id: id, name: name, values: values));
    }

    setState(() {
      _variations = variations;
      _isLoading = false;
    });
  }

  Future<void> _showAddVariationSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariationFormSheet(
        onSave: (name, values) async {
          final dbHelper = context.read<DatabaseHelper>();
          final db = await dbHelper.database;
          final now = DateTime.now().toIso8601String();
          final id = await db.insert(
            DatabaseConstants.tableProductVariations,
            {DatabaseConstants.colName: name, DatabaseConstants.colCreatedAt: now, DatabaseConstants.colUpdatedAt: now},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (id > 0) {
            for (final v in values) {
              await db.insert(DatabaseConstants.tableProductVariationValues, {
                DatabaseConstants.colVariationId: id,
                'value': v,
                DatabaseConstants.colCreatedAt: now,
              });
            }
          }
          _loadVariations();
        },
      ),
    );
  }

  Future<void> _showEditVariationSheet(_Variation variation) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariationFormSheet(
        initialName: variation.name,
        initialValues: variation.values.map((v) => v.value).toList(),
        onSave: (name, newValues) async {
          final dbHelper = context.read<DatabaseHelper>();
          final db = await dbHelper.database;
          final now = DateTime.now().toIso8601String();
          await db.update(
            DatabaseConstants.tableProductVariations,
            {DatabaseConstants.colName: name, DatabaseConstants.colUpdatedAt: now},
            where: '${DatabaseConstants.colId} = ?',
            whereArgs: [variation.id],
          );
          await db.delete(
            DatabaseConstants.tableProductVariationValues,
            where: '${DatabaseConstants.colVariationId} = ?',
            whereArgs: [variation.id],
          );
          for (final v in newValues) {
            await db.insert(DatabaseConstants.tableProductVariationValues, {
              DatabaseConstants.colVariationId: variation.id,
              'value': v,
              DatabaseConstants.colCreatedAt: now,
            });
          }
          _loadVariations();
        },
      ),
    );
  }

  Future<void> _deleteVariation(_Variation variation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('মুছে ফেলুন', style: TextStyle(color: cs.onSurface)),
          content: Text('"${variation.name}" এবং এর সব values মুছে ফেলতে চান?',
              style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('মুছুন'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final dbHelper = context.read<DatabaseHelper>();
    final db = await dbHelper.database;
    await db.delete(
      DatabaseConstants.tableProductVariations,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [variation.id],
    );
    if (!mounted) return;
    _loadVariations();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${variation.name}" মুছে ফেলা হয়েছে'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surface,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text('Variations', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18, color: cs.onSurface)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _variations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_outlined, size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('কোনো variation নেই', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('নিচের + বাটন চেপে variation যোগ করুন',
                          style: TextStyle(color: cs.outlineVariant, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _variations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _VariationCard(
                    variation: _variations[index],
                    onEdit: () => _showEditVariationSheet(_variations[index]),
                    onDelete: () => _deleteVariation(_variations[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVariationSheet,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Variation যোগ করুন'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
}

class _VariationCard extends StatelessWidget {
  final _Variation variation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariationCard({
    required this.variation,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    variation.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (variation.values.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('কোনো value নেই', style: TextStyle(fontSize: 12, color: cs.outlineVariant)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: variation.values.map((v) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      v.value,
                      style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.w500),
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VariationFormSheet extends StatefulWidget {
  final String? initialName;
  final List<String>? initialValues;
  final Future<void> Function(String name, List<String> values) onSave;

  const _VariationFormSheet({
    this.initialName,
    this.initialValues,
    required this.onSave,
  });

  @override
  State<_VariationFormSheet> createState() => _VariationFormSheetState();
}

class _VariationFormSheetState extends State<_VariationFormSheet> {
  late final TextEditingController _nameController;
  final TextEditingController _valueController = TextEditingController();
  late final List<String> _values;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _values = List<String>.from(widget.initialValues ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _addValue() {
    final v = _valueController.text.trim();
    if (v.isEmpty) return;
    if (_values.any((existing) => existing.toLowerCase() == v.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$v" ইতিমধ্যে আছে'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _values.add(v));
    _valueController.clear();
  }

  void _removeValue(String v) => setState(() => _values.remove(v));

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Variation নাম দিন'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _isSaving = true);
    await widget.onSave(name, List.from(_values));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.initialName == null ? 'নতুন Variation' : 'Variation সম্পাদনা',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: widget.initialName == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Variation নাম (যেমন: Color, Size)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 14),
            Text('Values', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Value লিখুন (যেমন: লাল, S, M)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _addValue(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addValue,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    minimumSize: const Size(48, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            if (_values.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _values.map((v) => Chip(
                  label: Text(v, style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer)),
                  backgroundColor: cs.primaryContainer,
                  deleteIconColor: cs.onPrimaryContainer.withValues(alpha: 0.6),
                  onDeleted: () => _removeValue(v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                )).toList(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('সংরক্ষণ করুন', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Variation {
  final int id;
  final String name;
  final List<_VariationValue> values;
  _Variation({required this.id, required this.name, required this.values});
}

class _VariationValue {
  final int id;
  final String value;
  _VariationValue({required this.id, required this.value});
}
