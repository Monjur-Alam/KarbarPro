import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String? description;
  final double price;
  final double? costPrice;
  final int stockQuantity;
  final String unit;
  final String? barcode;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.costPrice,
    this.stockQuantity = 0,
    this.unit = 'pcs',
    this.barcode,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        price,
        costPrice,
        stockQuantity,
        unit,
        barcode,
        imageUrl,
        createdAt,
        updatedAt,
      ];
}
