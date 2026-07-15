import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/product.dart';
import '../bloc/inventory_bloc.dart';

// ─── Row model ───────────────────────────────────────────────────────────────

class _VarRow {
  final Map<String, String> variations;
  final String directLabel;
  final int? variantId;
  final TextEditingController qtyCtrl;
  final TextEditingController purchaseCtrl;
  final TextEditingController sellingCtrl;
  final TextEditingController barcodeCtrl;

  _VarRow({
    this.variations = const {},
    this.directLabel = '',
    this.variantId,
    String qty = '',
    String purchase = '',
    String selling = '',
    String barcode = '',
  })  : qtyCtrl = TextEditingController(text: qty),
        purchaseCtrl = TextEditingController(text: purchase),
        sellingCtrl = TextEditingController(text: selling),
        barcodeCtrl = TextEditingController(text: barcode);

  String get label => directLabel.isNotEmpty ? directLabel : variations.values.join(' / ');

  void dispose() {
    qtyCtrl.dispose();
    purchaseCtrl.dispose();
    sellingCtrl.dispose();
    barcodeCtrl.dispose();
  }
}

// ─── Main Sheet ──────────────────────────────────────────────────────────────

class ProductFormSheet extends StatefulWidget {
  final Product? product;
  final ScaffoldMessengerState? parentMessenger;
  const ProductFormSheet({super.key, this.product, this.parentMessenger});

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _sharedPurchaseCtrl = TextEditingController();
  final _sharedSellingCtrl = TextEditingController();

  String? _category;
  String? _unit;
  File? _image;
  Map<String, dynamic>? _supplier;

  List<String> _categories = [];
  List<String> _units = [];

  // variations: type name → selected value names
  Map<String, List<String>> _selectedVariations = {};
  List<_VarRow> _rows = [];
  bool _samePrices = true;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _discountCtrl.addListener(_setState);
    _paidCtrl.addListener(_setState);
    _sharedPurchaseCtrl.addListener(_setState);
    _sharedSellingCtrl.addListener(_setState);

    if (_isEdit) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _descCtrl.text = '';
      _category = p.category;
      _unit = p.unit;
      if (p.imagePath != null && p.imagePath!.isNotEmpty) {
        _image = File(p.imagePath!);
      }
      // Pre-fill shared price controllers (shown when _samePrices = true)
      _sharedPurchaseCtrl.text = p.purchasePrice > 0 ? p.purchasePrice.toStringAsFixed(0) : '';
      _sharedSellingCtrl.text = p.sellingPrice > 0 ? p.sellingPrice.toStringAsFixed(0) : '';
      _rows = [
        _VarRow(
          variations: {},
          qty: p.currentStock.toString(),
          purchase: p.purchasePrice > 0 ? p.purchasePrice.toString() : '',
          selling: p.sellingPrice > 0 ? p.sellingPrice.toString() : '',
          barcode: p.barcode ?? '',
        ),
      ];
    } else {
      _rows = [_VarRow(variations: {}, barcode: _genBarcode(0))];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  void _setState() => setState(() {});

  void _snack(String message, {Color? color}) {
    final messenger = widget.parentMessenger ?? ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _sharedPurchaseCtrl.dispose();
    _sharedSellingCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  String _genBarcode(int index) =>
      'P${DateTime.now().millisecondsSinceEpoch}${index.toString().padLeft(3, '0')}';

  Future<void> _loadMeta() async {
    final dbHelper = context.read<DatabaseHelper>();
    final db = await dbHelper.database;
    final cats = await db.query(DatabaseConstants.tableProductCategories,
        orderBy: '${DatabaseConstants.colName} ASC');
    final units = await db.query(DatabaseConstants.tableProductUnits,
        orderBy: '${DatabaseConstants.colName} ASC');

    Map<String, dynamic>? loadedSupplier;
    if (_isEdit && widget.product!.supplierId != null) {
      final rows = await db.query(
        DatabaseConstants.tableCustomers,
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [widget.product!.supplierId],
      );
      if (rows.isNotEmpty) loadedSupplier = Map<String, dynamic>.from(rows.first);
    }

    List<_VarRow>? loadedRows;
    if (_isEdit && widget.product!.id != null) {
      final variantRows = await db.query(
        DatabaseConstants.tableProductVariants,
        where: 'product_id = ?',
        whereArgs: [widget.product!.id],
        orderBy: '${DatabaseConstants.colId} ASC',
      );
      if (variantRows.isNotEmpty) {
        loadedRows = variantRows.map((row) => _VarRow(
          directLabel: row[DatabaseConstants.colVariantLabel] as String? ?? '',
          variantId: row[DatabaseConstants.colId] as int?,
          qty: (row[DatabaseConstants.colCurrentStock] as int? ?? 0).toString(),
          purchase: ((row[DatabaseConstants.colPurchasePrice] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
          selling: ((row[DatabaseConstants.colSellingPrice] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
          barcode: row[DatabaseConstants.colBarcode] as String? ?? '',
        )).toList();
      }
    }

    if (!mounted) return;
    setState(() {
      _categories = cats.map((r) => r[DatabaseConstants.colName] as String).toList();
      _units = units.map((r) => r[DatabaseConstants.colName] as String).toList();
      if (loadedSupplier != null) _supplier = loadedSupplier;
      if (loadedRows != null && loadedRows.isNotEmpty) {
        for (final r in _rows) r.dispose();
        _rows = loadedRows;
        _sharedPurchaseCtrl.text = _rows.first.purchaseCtrl.text;
        _sharedSellingCtrl.text = _rows.first.sellingCtrl.text;
      }
    });
  }

  Future<void> _pickImage() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    if (!status.isGranted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ক্যামেরা'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('গ্যালারি'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await _picker.pickImage(source: source);
    if (file != null && mounted) {
      setState(() => _image = File(file.path));
    }
  }

  Future<void> _pickCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SimplePickerSheet(
        title: 'ক্যাটাগরি',
        items: _categories,
        selected: _category,
        onAdd: (val) async {
          final dbHelper = context.read<DatabaseHelper>();
          final db = await dbHelper.database;
          final now = DateTime.now().toIso8601String();
          await db.insert(
            DatabaseConstants.tableProductCategories,
            {DatabaseConstants.colName: val, DatabaseConstants.colCreatedAt: now, DatabaseConstants.colUpdatedAt: now},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await _loadMeta();
        },
      ),
    );
    if (result != null && mounted) setState(() => _category = result);
  }

  Future<void> _pickUnit() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SimplePickerSheet(
        title: 'ইউনিট',
        items: _units,
        selected: _unit,
        onAdd: (val) async {
          final dbHelper = context.read<DatabaseHelper>();
          final db = await dbHelper.database;
          final now = DateTime.now().toIso8601String();
          await db.insert(
            DatabaseConstants.tableProductUnits,
            {DatabaseConstants.colName: val, DatabaseConstants.colCreatedAt: now, DatabaseConstants.colUpdatedAt: now},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await _loadMeta();
        },
      ),
    );
    if (result != null && mounted) setState(() => _unit = result);
  }

  Future<void> _pickSupplier() async {
    final dbHelper = context.read<DatabaseHelper>();
    final db = await dbHelper.database;
    final suppliers = await db.query(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colCustomerType} = ?',
      whereArgs: ['supplier'],
      orderBy: '${DatabaseConstants.colName} ASC',
    );
    if (!mounted) return;
    if (suppliers.isEmpty) {
      _snack('কোনো supplier নেই। Customers সেকশনে যোগ করুন।');
      return;
    }
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierPickerSheet(suppliers: suppliers, selected: _supplier),
    );
    if (!mounted) return;
    if (result != null) setState(() => _supplier = result);
  }

  Future<void> _openVariationSelector() async {
    final result = await showModalBottomSheet<Map<String, List<String>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariationSelectorSheet(
        dbHelper: context.read<DatabaseHelper>(),
        initial: _selectedVariations,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedVariations = result;
      _rebuildRows();
    });
  }

  void _rebuildRows() {
    final oldRows = List<_VarRow>.from(_rows);
    final combinations = _cartesian(_selectedVariations);

    _rows = List.generate(combinations.length, (i) {
      final combo = combinations[i];
      final oldBarcode = i < oldRows.length ? oldRows[i].barcodeCtrl.text : '';
      final oldQty = i < oldRows.length ? oldRows[i].qtyCtrl.text : '';
      return _VarRow(
        variations: combo,
        qty: oldQty,
        barcode: oldBarcode.isNotEmpty ? oldBarcode : _genBarcode(i),
      );
    });

    for (final r in oldRows) {
      r.dispose();
    }
  }

  List<Map<String, String>> _cartesian(Map<String, List<String>> selections) {
    if (selections.isEmpty) return [{}];
    final types = selections.keys.toList();
    List<Map<String, String>> result = [{}];
    for (final type in types) {
      final values = selections[type]!;
      if (values.isEmpty) continue;
      final next = <Map<String, String>>[];
      for (final existing in result) {
        for (final val in values) {
          next.add({...existing, type: val});
        }
      }
      result = next;
    }
    return result.isEmpty ? [{}] : result;
  }

  // ── Summary calculations ──────────────────────────────────────────────────

  int get _totalItems {
    return _rows.fold(0, (sum, r) => sum + (int.tryParse(r.qtyCtrl.text) ?? 0));
  }

  double get _netTotal {
    double total = 0;
    if (_samePrices) {
      final p = double.tryParse(_sharedPurchaseCtrl.text) ?? 0;
      total = p * _totalItems;
    } else {
      for (final r in _rows) {
        final qty = int.tryParse(r.qtyCtrl.text) ?? 0;
        final p = double.tryParse(r.purchaseCtrl.text) ?? 0;
        total += qty * p;
      }
    }
    return total;
  }

  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _due => (_netTotal - _discount - _paid).clamp(0, double.infinity);

  // ── Save & Print ──────────────────────────────────────────────────────────

  Future<void> _saveAndPrint() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('পণ্যের নাম দিন', color: Colors.orange);
      return;
    }
    setState(() => _isSaving = true);

    final dbHelper = context.read<DatabaseHelper>();
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // Ensure category persisted
    if (_category != null && _category!.isNotEmpty) {
      await db.insert(
        DatabaseConstants.tableProductCategories,
        {DatabaseConstants.colName: _category, DatabaseConstants.colCreatedAt: now, DatabaseConstants.colUpdatedAt: now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final sharedPurchase = double.tryParse(_sharedPurchaseCtrl.text) ?? 0;
    final sharedSelling = double.tryParse(_sharedSellingCtrl.text) ?? 0;

    final rowsToSave = _isEdit ? _rows : _rows.where((r) => (int.tryParse(r.qtyCtrl.text) ?? 0) > 0).toList();

    if (rowsToSave.isEmpty && !_isEdit) {
      setState(() => _isSaving = false);
      _snack('অন্তত একটি row-এ পরিমাণ দিন');
      return;
    }

    final totalQty = rowsToSave.fold(0, (s, r) => s + (int.tryParse(r.qtyCtrl.text) ?? 0));
    final firstPurchase = _samePrices ? sharedPurchase : (double.tryParse(rowsToSave.first.purchaseCtrl.text) ?? 0);
    final firstSelling = _samePrices ? sharedSelling : (double.tryParse(rowsToSave.first.sellingCtrl.text) ?? 0);
    final isSingleVariant = rowsToSave.length == 1;
    final singleBarcode = isSingleVariant ? rowsToSave.first.barcodeCtrl.text.trim() : null;

    final productData = {
      DatabaseConstants.colName: name,
      DatabaseConstants.colCategory: _category,
      DatabaseConstants.colUnit: _unit ?? 'pcs',
      DatabaseConstants.colCurrentStock: totalQty,
      DatabaseConstants.colPurchasePrice: firstPurchase > 0 ? firstPurchase : 0.01,
      DatabaseConstants.colSellingPrice: firstSelling > 0 ? firstSelling : 0.01,
      DatabaseConstants.colBarcode: (singleBarcode != null && singleBarcode.isNotEmpty) ? singleBarcode : null,
      DatabaseConstants.colImagePath: _image?.path,
      DatabaseConstants.colMinStockAlert: 5,
      DatabaseConstants.colIsActive: 1,
      DatabaseConstants.colIsSynced: 0,
      DatabaseConstants.colVariationsJson: null,
      DatabaseConstants.colSupplierId: _supplier?[DatabaseConstants.colId],
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
    };

    int productId;
    if (_isEdit && widget.product!.id != null) {
      productId = widget.product!.id!;
      await db.update(
        DatabaseConstants.tableProducts,
        productData,
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [productId],
      );
      await db.delete(
        DatabaseConstants.tableProductVariants,
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    } else {
      productId = await db.insert(DatabaseConstants.tableProducts, productData,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final row in rowsToSave) {
      final purchase = _samePrices ? sharedPurchase : (double.tryParse(row.purchaseCtrl.text) ?? 0);
      final selling = _samePrices ? sharedSelling : (double.tryParse(row.sellingCtrl.text) ?? 0);
      final variantBarcode = row.barcodeCtrl.text.trim();
      await db.insert(DatabaseConstants.tableProductVariants, {
        'product_id': productId,
        DatabaseConstants.colVariantLabel: row.label.isEmpty ? null : row.label,
        DatabaseConstants.colBarcode: variantBarcode.isNotEmpty ? variantBarcode : null,
        DatabaseConstants.colPurchasePrice: purchase > 0 ? purchase : 0.01,
        DatabaseConstants.colSellingPrice: selling > 0 ? selling : 0.01,
        DatabaseConstants.colCurrentStock: int.tryParse(row.qtyCtrl.text) ?? 0,
        DatabaseConstants.colMinStockAlert: 5,
        DatabaseConstants.colIsActive: 1,
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      });
    }

    // Record supplier due in ledger (only for new purchases, not edits)
    if (!_isEdit && _due > 0 && _supplier != null) {
      final supplierId = _supplier![DatabaseConstants.colId] as int;
      await db.rawUpdate('''
        UPDATE ${DatabaseConstants.tableCustomers}
        SET ${DatabaseConstants.colCurrentCreditBalance} = ${DatabaseConstants.colCurrentCreditBalance} + ?,
            ${DatabaseConstants.colTotalCredit} = ${DatabaseConstants.colTotalCredit} + ?,
            ${DatabaseConstants.colTotalPurchases} = ${DatabaseConstants.colTotalPurchases} + ?,
            ${DatabaseConstants.colUpdatedAt} = ?
        WHERE ${DatabaseConstants.colId} = ?
      ''', [_due, _netTotal, _netTotal, now, supplierId]);

      final supplierRows = await db.query(
        DatabaseConstants.tableCustomers,
        columns: [DatabaseConstants.colCurrentCreditBalance],
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [supplierId],
      );
      final newBalance = supplierRows.isNotEmpty
          ? (supplierRows.first[DatabaseConstants.colCurrentCreditBalance] as num).toDouble()
          : _due;

      await db.insert(DatabaseConstants.tableCustomerTransactions, {
        DatabaseConstants.colCustomerId: supplierId,
        DatabaseConstants.colTransactionType: 'sale',
        DatabaseConstants.colAmount: _due,
        DatabaseConstants.colBalanceAfter: newBalance,
        DatabaseConstants.colDescription: 'পণ্য ক্রয় - $name',
        DatabaseConstants.colTransactionDate: now,
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colTransactionSource: 'product_purchase',
        DatabaseConstants.colIsSynced: 0,
      });
    }

    if (!mounted) return;
    context.read<InventoryBloc>().add(LoadProducts());

    // Build PDF
    Uint8List? pdfBytes;
    try {
      pdfBytes = await _buildPdf(name, rowsToSave, sharedPurchase, sharedSelling);
    } catch (_) {}

    setState(() => _isSaving = false);
    if (!mounted) return;
    Navigator.pop(context);

    if (pdfBytes != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PrintPreviewPage(pdfBytes: pdfBytes!, title: 'Barcode Print'),
        ),
      );
    }
  }

  Future<Uint8List> _buildPdf(String baseName, List<_VarRow> rows, double sharedPurchase, double sharedSelling) async {
    final regularData = await rootBundle.load('assets/fonts/HindSiliguri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/HindSiliguri-Bold.ttf');
    final font = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    const w = 50.0; // mm
    const h = 30.0; // mm
    final pageFormat = PdfPageFormat(w * PdfPageFormat.mm, h * PdfPageFormat.mm, marginAll: 1.5 * PdfPageFormat.mm);

    final pdf = pw.Document();

    for (final row in rows) {
      final qty = int.tryParse(row.qtyCtrl.text) ?? 0;
      if (qty <= 0) continue;
      final productName = row.label.isEmpty ? baseName : '$baseName - ${row.label}';
      final selling = _samePrices ? sharedSelling : (double.tryParse(row.sellingCtrl.text) ?? sharedSelling);
      final barcode = row.barcodeCtrl.text.trim();
      if (barcode.isEmpty) continue;

      for (int i = 0; i < qty; i++) {
        pdf.addPage(pw.Page(
          pageFormat: pageFormat,
          build: (_) => pw.Container(
            width: double.infinity,
            height: double.infinity,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(productName,
                    style: pw.TextStyle(font: boldFont, fontSize: 7.5),
                    textAlign: pw.TextAlign.center,
                    maxLines: 2),
                if (selling > 0)
                  pw.Text('Tk ${selling.toStringAsFixed(0)}',
                      style: pw.TextStyle(font: boldFont, fontSize: 9),
                      textAlign: pw.TextAlign.center),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcode,
                  height: 10 * PdfPageFormat.mm,
                  width: (w - 5) * PdfPageFormat.mm,
                  drawText: false,
                ),
                pw.Text(barcode,
                    style: pw.TextStyle(font: font, fontSize: 5),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        ));
      }
    }

    return pdf.save();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle + Title
                _Header(isEdit: _isEdit),

                // Body
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.only(bottom: mq.viewInsets.bottom + 16),
                    children: [
                      // 1. Image
                      _ImagePicker(image: _image, onTap: _pickImage),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 2. Name
                            _label('পণ্যের নাম *', cs),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDeco('পণ্যের নাম লিখুন'),
                            ),
                            const SizedBox(height: 14),

                            // 3. Category | Unit
                            Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _label('ক্যাটাগরি', cs),
                                  const SizedBox(height: 6),
                                  _TapField(
                                    value: _category,
                                    placeholder: 'ক্যাটাগরি বাছুন',
                                    onTap: _pickCategory,
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _label('ইউনিট', cs),
                                  const SizedBox(height: 6),
                                  _TapField(
                                    value: _unit,
                                    placeholder: 'ইউনিট বাছুন',
                                    onTap: _pickUnit,
                                  ),
                                ]),
                              ),
                            ]),
                            const SizedBox(height: 14),

                            // 4. Description
                            _label('বিবরণ', cs),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _descCtrl,
                              maxLines: 2,
                              decoration: _inputDeco('পণ্যের বিবরণ'),
                            ),
                            const SizedBox(height: 14),

                            // 5. Supplier
                            _label('সরবরাহকারী (ঐচ্ছিক)', cs),
                            const SizedBox(height: 6),
                            _SupplierField(
                              supplier: _supplier,
                              onTap: _pickSupplier,
                              onClear: () => setState(() => _supplier = null),
                            ),
                            const SizedBox(height: 14),

                            // 6. Variation selector (only for new items)
                            if (!_isEdit) ...[
                              _VariationSelector(
                                selected: _selectedVariations,
                                onSelect: _openVariationSelector,
                              ),
                              const SizedBox(height: 14),
                            ],

                            // 7. Matrix header (Same Price switch)
                            _MatrixHeader(
                              samePrices: _samePrices,
                              onToggle: (v) => setState(() => _samePrices = v),
                              sharedPurchaseCtrl: _sharedPurchaseCtrl,
                              sharedSellingCtrl: _sharedSellingCtrl,
                            ),
                            const SizedBox(height: 8),

                            // 8. Matrix rows
                            ..._rows.asMap().entries.map((e) => _MatrixRow(
                                  index: e.key,
                                  row: e.value,
                                  samePrices: _samePrices,
                                  onChanged: () => setState(() {}),
                                  onRegenBarcode: () => setState(
                                      () => e.value.barcodeCtrl.text = _genBarcode(e.key)),
                                )),

                            const SizedBox(height: 12),

                            // 9. Summary
                            _SummaryBox(
                              totalItems: _totalItems,
                              netTotal: _netTotal,
                              cs: cs,
                            ),
                            const SizedBox(height: 14),

                            // 10. Payment (new purchases only)
                            if (!_isEdit) ...[
                              _PaymentSection(
                                discountCtrl: _discountCtrl,
                                paidCtrl: _paidCtrl,
                                due: _due,
                                cs: cs,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Save & Print button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, -2))],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAndPrint,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_alt_rounded, size: 20),
                      label: Text(
                        _isEdit ? 'সংরক্ষণ ও Print' : 'সংরক্ষণ ও Barcode Print',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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

  Widget _label(String text, ColorScheme cs) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isEdit;
  const _Header({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Text(
                  isEdit ? 'পণ্য সম্পাদনা' : 'নতুন পণ্য যোগ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  const _ImagePicker({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        color: cs.surfaceContainerHighest,
        child: image != null && image!.existsSync()
            ? Image.file(image!, fit: BoxFit.cover)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 44, color: cs.outlineVariant),
                  const SizedBox(height: 8),
                  Text('ছবি যোগ করুন', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                ],
              ),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  const _TapField({required this.value, required this.placeholder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null ? cs.onSurface : cs.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SupplierField extends StatelessWidget {
  final Map<String, dynamic>? supplier;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _SupplierField({required this.supplier, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = supplier?[DatabaseConstants.colName] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name ?? 'সরবরাহকারী বাছুন',
                style: TextStyle(fontSize: 14, color: name != null ? cs.onSurface : cs.onSurfaceVariant),
              ),
            ),
            if (name != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.clear, size: 18, color: cs.onSurfaceVariant),
              )
            else
              Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _VariationSelector extends StatelessWidget {
  final Map<String, List<String>> selected;
  final VoidCallback onSelect;
  const _VariationSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection = selected.values.any((v) => v.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Variations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const Spacer(),
            TextButton(
              onPressed: onSelect,
              child: const Text('বাছাই করুন'),
            ),
          ],
        ),
        if (hasSelection) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selected.entries
                .where((e) => e.value.isNotEmpty)
                .map((e) => Chip(
                      label: Text('${e.key}: ${e.value.join(", ")}',
                          style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _MatrixHeader extends StatelessWidget {
  final bool samePrices;
  final ValueChanged<bool> onToggle;
  final TextEditingController sharedPurchaseCtrl;
  final TextEditingController sharedSellingCtrl;
  const _MatrixHeader({
    required this.samePrices,
    required this.onToggle,
    required this.sharedPurchaseCtrl,
    required this.sharedSellingCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('পণ্যের বিবরণ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const Spacer(),
            Text('একই দাম', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(width: 4),
            Switch(value: samePrices, onChanged: onToggle),
          ],
        ),
        if (samePrices) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sharedPurchaseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'ক্রয়মূল্য',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: sharedSellingCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'বিক্রয়মূল্য',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MatrixRow extends StatelessWidget {
  final int index;
  final _VarRow row;
  final bool samePrices;
  final VoidCallback onChanged;
  final VoidCallback onRegenBarcode;

  const _MatrixRow({
    required this.index,
    required this.row,
    required this.samePrices,
    required this.onChanged,
    required this.onRegenBarcode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: cs.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Variation chips
          if (row.variations.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: row.variations.entries.map((e) => Chip(
                    label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11)),
                    backgroundColor: cs.primaryContainer,
                    labelStyle: TextStyle(color: cs.onPrimaryContainer),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  )).toList(),
            ),
            const SizedBox(height: 8),
          ],

          // Qty row + price row (or just qty if samePrices)
          Row(
            children: [
              Expanded(
                child: _miniField('পরিমাণ', row.qtyCtrl, TextInputType.number, onChanged),
              ),
              if (!samePrices) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _miniField('ক্রয়মূল্য', row.purchaseCtrl,
                      const TextInputType.numberWithOptions(decimal: true), onChanged),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniField('বিক্রয়মূল্য', row.sellingCtrl,
                      const TextInputType.numberWithOptions(decimal: true), onChanged),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Barcode row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.barcodeCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: cs.primary, size: 20),
                tooltip: 'নতুন barcode',
                onPressed: onRegenBarcode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniField(String label, TextEditingController ctrl, TextInputType keyboard, VoidCallback onChange) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      onChanged: (_) => onChange(),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final int totalItems;
  final double netTotal;
  final ColorScheme cs;
  const _SummaryBox({required this.totalItems, required this.netTotal, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('মোট পরিমাণ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              Text('$totalItems pcs', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('নেট মোট', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              Text('৳ ${netTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  final TextEditingController discountCtrl;
  final TextEditingController paidCtrl;
  final double due;
  final ColorScheme cs;
  const _PaymentSection({
    required this.discountCtrl,
    required this.paidCtrl,
    required this.due,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('পেমেন্ট', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'ছাড়',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: paidCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'প্রদত্ত',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dueColor = due > 0 ? Colors.red : Colors.green;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: dueColor.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dueColor.withValues(alpha: isDark ? 0.45 : 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('বাকি', style: TextStyle(fontWeight: FontWeight.w600, color: dueColor)),
                Text('৳ ${due.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dueColor)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Simple Picker Sheet ─────────────────────────────────────────────────────

class _SimplePickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final Future<void> Function(String) onAdd;
  const _SimplePickerSheet({required this.title, required this.items, this.selected, required this.onAdd});

  @override
  State<_SimplePickerSheet> createState() => _SimplePickerSheetState();
}

class _SimplePickerSheetState extends State<_SimplePickerSheet> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.items);
  }

  Future<void> _addNew() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('নতুন ${widget.title}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) { if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim()); },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () { if (ctrl.text.trim().isNotEmpty) Navigator.pop(ctx, ctrl.text.trim()); },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await widget.onAdd(result);
      if (mounted) setState(() { if (!_items.contains(result)) _items.add(result); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('কোনো ${widget.title} নেই', style: TextStyle(color: cs.onSurfaceVariant))),
            )
          else
            ..._items.map((item) => ListTile(
              dense: true,
              title: Text(item),
              trailing: widget.selected == item ? Icon(Icons.check_circle, color: cs.primary) : null,
              onTap: () => Navigator.pop(context, item),
            )),
          const Divider(),
          ListTile(
            dense: true,
            leading: Icon(Icons.add, color: cs.primary),
            title: Text('নতুন ${widget.title} যোগ করুন', style: TextStyle(color: cs.primary)),
            onTap: _addNew,
          ),
        ],
      ),
    );
  }
}

// ─── Supplier Picker Sheet ───────────────────────────────────────────────────

class _SupplierPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> suppliers;
  final Map<String, dynamic>? selected;
  const _SupplierPickerSheet({required this.suppliers, this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('সরবরাহকারী বাছুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...suppliers.map((s) {
            final name = s[DatabaseConstants.colName] as String? ?? '';
            final phone = s[DatabaseConstants.colPhone] as String? ?? '';
            final isSelected = selected?[DatabaseConstants.colId] == s[DatabaseConstants.colId];
            return ListTile(
              leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
              title: Text(name),
              subtitle: phone.isNotEmpty ? Text(phone) : null,
              trailing: isSelected ? Icon(Icons.check_circle, color: cs.primary) : null,
              onTap: () => Navigator.pop(context, s),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Variation Selector Sheet ─────────────────────────────────────────────────

class _VariationSelectorSheet extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final Map<String, List<String>> initial;
  const _VariationSelectorSheet({required this.dbHelper, required this.initial});

  @override
  State<_VariationSelectorSheet> createState() => _VariationSelectorSheetState();
}

class _VariationSelectorSheetState extends State<_VariationSelectorSheet> {
  // type name → { value → isSelected }
  Map<String, Map<String, bool>> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await widget.dbHelper.database;
    final types = await db.query(DatabaseConstants.tableProductVariations,
        orderBy: '${DatabaseConstants.colName} ASC');

    final result = <String, Map<String, bool>>{};
    for (final t in types) {
      final typeName = t[DatabaseConstants.colName] as String;
      final typeId = t[DatabaseConstants.colId] as int;
      final prevSelected = widget.initial[typeName] ?? [];
      final values = await db.query(
        DatabaseConstants.tableProductVariationValues,
        where: '${DatabaseConstants.colVariationId} = ?',
        whereArgs: [typeId],
        orderBy: '${DatabaseConstants.colId} ASC',
      );
      result[typeName] = {
        for (final v in values)
          (v['value'] as String): prevSelected.contains(v['value'] as String),
      };
    }
    if (mounted) setState(() { _data = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Variations বাছাই', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('কোনো variation নেই। Drawer > Manage > Variations থেকে যোগ করুন।',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _data.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, top: 4),
                          child: Text(entry.key,
                              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: entry.value.entries.map((ve) => FilterChip(
                            label: Text(ve.key),
                            selected: ve.value,
                            onSelected: (v) => setState(() => _data[entry.key]![ve.key] = v),
                          )).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final result = <String, List<String>>{};
                for (final entry in _data.entries) {
                  final selected = entry.value.entries.where((e) => e.value).map((e) => e.key).toList();
                  if (selected.isNotEmpty) result[entry.key] = selected;
                }
                Navigator.pop(context, result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('প্রয়োগ করুন'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Print Preview Page ──────────────────────────────────────────────────────

class _PrintPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  const _PrintPreviewPage({required this.pdfBytes, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canDebug: false,
        scrollViewDecoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerLow : Colors.grey.shade300,
        ),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: isDark ? Colors.black45 : Colors.black26, blurRadius: 4, spreadRadius: 1)],
        ),
        loadingWidget: Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
      ),
    );
  }
}
