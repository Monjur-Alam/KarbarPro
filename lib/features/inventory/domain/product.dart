import 'package:equatable/equatable.dart';
import 'product_variant.dart';

class Product extends Equatable {
  final int? id;
  final String name;
  final String? nameBengali;
  final String? category;
  final double purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final int minStockAlert;
  final String unit;
  final String? barcode;
  final String? size;
  final String? imagePath;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? syncedAt;
  final bool isSynced;
  final String? variationsJson;
  final int? supplierId;
  final List<ProductVariant>? variants;

  const Product({
    this.id,
    required this.name,
    this.nameBengali,
    this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    this.currentStock = 0,
    this.minStockAlert = 5,
    this.unit = 'pcs',
    this.barcode,
    this.size,
    this.imagePath,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.syncedAt,
    this.isSynced = false,
    this.variationsJson,
    this.supplierId,
    this.variants,
  });

  Product copyWith({
    int? id,
    String? name,
    String? nameBengali,
    String? category,
    double? purchasePrice,
    double? sellingPrice,
    int? currentStock,
    int? minStockAlert,
    String? unit,
    String? barcode,
    String? size,
    String? imagePath,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isSynced,
    String? variationsJson,
    int? supplierId,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      nameBengali: nameBengali ?? this.nameBengali,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      unit: unit ?? this.unit,
      barcode: barcode ?? this.barcode,
      size: size ?? this.size,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isSynced: isSynced ?? this.isSynced,
      variationsJson: variationsJson ?? this.variationsJson,
      supplierId: supplierId ?? this.supplierId,
      variants: variants ?? this.variants,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        nameBengali,
        category,
        purchasePrice,
        sellingPrice,
        currentStock,
        minStockAlert,
        unit,
        barcode,
        size,
        imagePath,
        isActive,
        createdAt,
        updatedAt,
        syncedAt,
        isSynced,
        variationsJson,
        supplierId,
        variants,
      ];
}
