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
      if (stockFilter == 'low') {
        whereClauses.add('${DatabaseConstants.colCurrentStock} <= ${DatabaseConstants.colMinStockAlert}');
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
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) return;
    final productModel = ProductModel.fromEntity(product);
    await _dbHelper.update(DatabaseConstants.tableProducts, productModel.toJson());
  }

  Future<void> deleteProduct(int id) async {
    await _dbHelper.delete(DatabaseConstants.tableProducts, id);
  }
}
