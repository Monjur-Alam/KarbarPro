import 'package:equatable/equatable.dart';

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
  final String? imagePath;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? syncedAt;
  final bool isSynced;

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
    this.imagePath,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.syncedAt,
    this.isSynced = false,
  });

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
        imagePath,
        isActive,
        createdAt,
        updatedAt,
        syncedAt,
        isSynced,
      ];
}
