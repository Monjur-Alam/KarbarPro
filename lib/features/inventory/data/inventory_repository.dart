import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/database_constants.dart';
import '../domain/product.dart';
import 'product_model.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper;

  InventoryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<Product>> getProducts() async {
    final result = await _dbHelper.queryAll(DatabaseConstants.tableProducts);
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
