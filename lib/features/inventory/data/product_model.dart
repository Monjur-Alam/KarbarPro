import '../../../../core/constants/database_constants.dart';
import '../domain/product.dart';

class ProductModel extends Product {
  const ProductModel({
    super.id,
    required super.name,
    super.nameBengali,
    super.category,
    required super.purchasePrice,
    required super.sellingPrice,
    super.currentStock,
    super.minStockAlert,
    super.unit,
    super.barcode,
    super.size,
    super.imagePath,
    super.isActive,
    super.createdAt,
    super.updatedAt,
    super.syncedAt,
    super.isSynced,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json[DatabaseConstants.colId],
      name: json[DatabaseConstants.colName],
      nameBengali: json[DatabaseConstants.colNameBengali],
      category: json[DatabaseConstants.colCategory],
      purchasePrice: (json[DatabaseConstants.colPurchasePrice] as num).toDouble(),
      sellingPrice: (json[DatabaseConstants.colSellingPrice] as num).toDouble(),
      currentStock: json[DatabaseConstants.colCurrentStock] ?? 0,
      minStockAlert: json[DatabaseConstants.colMinStockAlert] ?? 5,
      unit: json[DatabaseConstants.colUnit] ?? 'pcs',
      barcode: json[DatabaseConstants.colBarcode],
      size: json[DatabaseConstants.colSize],
      imagePath: json[DatabaseConstants.colImagePath],
      isActive: json[DatabaseConstants.colIsActive] == 1,
      createdAt: json[DatabaseConstants.colCreatedAt] != null 
          ? DateTime.parse(json[DatabaseConstants.colCreatedAt]) 
          : null,
      updatedAt: json[DatabaseConstants.colUpdatedAt] != null 
          ? DateTime.parse(json[DatabaseConstants.colUpdatedAt]) 
          : null,
      syncedAt: json[DatabaseConstants.colSyncedAt] != null 
          ? DateTime.parse(json[DatabaseConstants.colSyncedAt]) 
          : null,
      isSynced: json[DatabaseConstants.colIsSynced] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) DatabaseConstants.colId: id,
      DatabaseConstants.colName: name,
      DatabaseConstants.colNameBengali: nameBengali,
      DatabaseConstants.colCategory: category,
      DatabaseConstants.colPurchasePrice: purchasePrice,
      DatabaseConstants.colSellingPrice: sellingPrice,
      DatabaseConstants.colCurrentStock: currentStock,
      DatabaseConstants.colMinStockAlert: minStockAlert,
      DatabaseConstants.colUnit: unit,
      DatabaseConstants.colBarcode: barcode,
      DatabaseConstants.colSize: size,
      DatabaseConstants.colImagePath: imagePath,
      DatabaseConstants.colIsActive: isActive ? 1 : 0,
      if (createdAt != null) DatabaseConstants.colCreatedAt: createdAt!.toIso8601String(),
      if (updatedAt != null) DatabaseConstants.colUpdatedAt: updatedAt!.toIso8601String(),
      if (syncedAt != null) DatabaseConstants.colSyncedAt: syncedAt!.toIso8601String(),
      DatabaseConstants.colIsSynced: isSynced ? 1 : 0,
    };
  }

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      nameBengali: product.nameBengali,
      category: product.category,
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      currentStock: product.currentStock,
      minStockAlert: product.minStockAlert,
      unit: product.unit,
      barcode: product.barcode,
      size: product.size,
      imagePath: product.imagePath,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      syncedAt: product.syncedAt,
      isSynced: product.isSynced,
    );
  }
}
