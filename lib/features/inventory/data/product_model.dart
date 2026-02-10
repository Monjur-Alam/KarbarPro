import '../../../../core/constants/database_constants.dart';
import '../domain/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    super.description,
    required super.price,
    super.costPrice,
    super.stockQuantity,
    super.unit,
    super.barcode,
    super.imageUrl,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json[DatabaseConstants.colId],
      name: json[DatabaseConstants.colName],
      description: json[DatabaseConstants.colDescription],
      price: (json[DatabaseConstants.colPrice] as num).toDouble(),
      costPrice: json[DatabaseConstants.colCostPrice] != null
          ? (json[DatabaseConstants.colCostPrice] as num).toDouble()
          : null,
      stockQuantity: json[DatabaseConstants.colStockQuantity] ?? 0,
      unit: json[DatabaseConstants.colUnit] ?? 'pcs',
      barcode: json[DatabaseConstants.colBarcode],
      imageUrl: json[DatabaseConstants.colImageUrl],
      createdAt: DateTime.parse(json[DatabaseConstants.colCreatedAt]),
      updatedAt: DateTime.parse(json[DatabaseConstants.colUpdatedAt]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      DatabaseConstants.colId: id,
      DatabaseConstants.colName: name,
      DatabaseConstants.colDescription: description,
      DatabaseConstants.colPrice: price,
      DatabaseConstants.colCostPrice: costPrice,
      DatabaseConstants.colStockQuantity: stockQuantity,
      DatabaseConstants.colUnit: unit,
      DatabaseConstants.colBarcode: barcode,
      DatabaseConstants.colImageUrl: imageUrl,
      DatabaseConstants.colCreatedAt: createdAt.toIso8601String(),
      DatabaseConstants.colUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      costPrice: product.costPrice,
      stockQuantity: product.stockQuantity,
      unit: product.unit,
      barcode: product.barcode,
      imageUrl: product.imageUrl,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );
  }
}
