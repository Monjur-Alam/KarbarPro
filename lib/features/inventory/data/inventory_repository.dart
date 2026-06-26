import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/database_constants.dart';
import '../domain/product.dart';
import 'product_model.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper;

  InventoryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<Product>> getProducts({
    String? searchQuery,
    String? category,
    String? stockFilter, // 'low', 'out'
    String sortBy = 'latest', // 'latest', 'name_asc', 'name_desc', 'quantity_high', 'quantity_low'
  }) async {
    final db = await _dbHelper.database;
    
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('${DatabaseConstants.colName} LIKE ?');
      whereArgs.add('%$searchQuery%');
    }

    // Category Filter
    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('${DatabaseConstants.colCategory} = ?');
      whereArgs.add(category);
    }

    // Stock Filter
    if (stockFilter != null) {
      if (stockFilter == 'in_stock') {
        whereClauses.add('${DatabaseConstants.colCurrentStock} > 0');
      } else if (stockFilter == 'low') {
        whereClauses.add('${DatabaseConstants.colCurrentStock} <= ${DatabaseConstants.colMinStockAlert} AND ${DatabaseConstants.colCurrentStock} > 0');
      } else if (stockFilter == 'out') {
        whereClauses.add('${DatabaseConstants.colCurrentStock} <= 0');
      }
    }

    // Sort
    String orderBy = '${DatabaseConstants.colUpdatedAt} DESC';
    switch (sortBy) {
      case 'name_asc':
        orderBy = '${DatabaseConstants.colName} ASC';
        break;
      case 'name_desc':
        orderBy = '${DatabaseConstants.colName} DESC';
        break;
      case 'quantity_high':
        orderBy = '${DatabaseConstants.colCurrentStock} DESC';
        break;
      case 'quantity_low':
        orderBy = '${DatabaseConstants.colCurrentStock} ASC';
        break;
      case 'latest':
      default:
        orderBy = '${DatabaseConstants.colUpdatedAt} DESC';
        break;
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final result = await db.query(
      DatabaseConstants.tableProducts,
      where: whereString,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    
    return result.map((json) => ProductModel.fromJson(json)).toList();
  }

  Future<void> addProduct(Product product) async {
    final productModel = ProductModel.fromEntity(product);
    await _dbHelper.insert(DatabaseConstants.tableProducts, productModel.toJson());
    await _ensureCategoryExists(product.category);
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) return;
    final productModel = ProductModel.fromEntity(product);
    await _dbHelper.update(DatabaseConstants.tableProducts, productModel.toJson());
    await _ensureCategoryExists(product.category);
  }

  Future<void> _ensureCategoryExists(String? category) async {
    if (category == null || category.isEmpty) return;
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      DatabaseConstants.tableProductCategories,
      {
        DatabaseConstants.colName: category,
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteProduct(int id) async {
    await _dbHelper.delete(DatabaseConstants.tableProducts, id);
  }

  Future<List<String>> getAllCategories() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT ${DatabaseConstants.colName}
      FROM ${DatabaseConstants.tableProductCategories}
      ORDER BY ${DatabaseConstants.colName} ASC
    ''');
    return result.map((r) => r[DatabaseConstants.colName] as String).toList();
  }
}
