import '../../../../core/constants/database_constants.dart';
import '../domain/product_variant.dart';

class ProductVariantModel extends ProductVariant {
  const ProductVariantModel({
    super.id,
    required super.productId,
    super.label,
    super.barcode,
    required super.purchasePrice,
    required super.sellingPrice,
    super.currentStock,
    super.minStockAlert,
    super.isActive,
    super.createdAt,
    super.updatedAt,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json[DatabaseConstants.colId] as int?,
      productId: json['product_id'] as int,
      label: json[DatabaseConstants.colVariantLabel] as String?,
      barcode: json[DatabaseConstants.colBarcode] as String?,
      purchasePrice: (json[DatabaseConstants.colPurchasePrice] as num?)?.toDouble() ?? 0.01,
      sellingPrice: (json[DatabaseConstants.colSellingPrice] as num?)?.toDouble() ?? 0.01,
      currentStock: json[DatabaseConstants.colCurrentStock] as int? ?? 0,
      minStockAlert: json[DatabaseConstants.colMinStockAlert] as int? ?? 5,
      isActive: (json[DatabaseConstants.colIsActive] as int? ?? 1) == 1,
      createdAt: json[DatabaseConstants.colCreatedAt] != null
          ? DateTime.tryParse(json[DatabaseConstants.colCreatedAt] as String)
          : null,
      updatedAt: json[DatabaseConstants.colUpdatedAt] != null
          ? DateTime.tryParse(json[DatabaseConstants.colUpdatedAt] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson(int productId) {
    return {
      if (id != null) DatabaseConstants.colId: id,
      'product_id': productId,
      DatabaseConstants.colVariantLabel: label,
      DatabaseConstants.colBarcode: barcode,
      DatabaseConstants.colPurchasePrice: purchasePrice,
      DatabaseConstants.colSellingPrice: sellingPrice,
      DatabaseConstants.colCurrentStock: currentStock,
      DatabaseConstants.colMinStockAlert: minStockAlert,
      DatabaseConstants.colIsActive: isActive ? 1 : 0,
      if (createdAt != null) DatabaseConstants.colCreatedAt: createdAt!.toIso8601String(),
      if (updatedAt != null) DatabaseConstants.colUpdatedAt: updatedAt!.toIso8601String(),
    };
  }
}
