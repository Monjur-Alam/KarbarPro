class ProductVariant {
  final int? id;
  final int productId;
  final String? label;
  final String? barcode;
  final double purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final int minStockAlert;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductVariant({
    this.id,
    required this.productId,
    this.label,
    this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    this.currentStock = 0,
    this.minStockAlert = 5,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });
}
