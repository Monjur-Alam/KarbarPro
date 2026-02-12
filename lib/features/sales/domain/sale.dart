import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double purchasePrice; // For profit calculation
  final double subTotal;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.purchasePrice,
    required this.subTotal,
  });

  double get profit => (unitPrice - purchasePrice) * quantity;

  @override
  List<Object?> get props => [id, saleId, productId, productName, quantity, unitPrice, purchasePrice, subTotal];
}

class Sale extends Equatable {
  final int? id;
  final String invoiceId;
  final int? customerId;
  final String? customerName; // Optional display name
  final double totalAmount;
  final double discount;
  final double paidAmount;
  final String paymentMethod;
  final DateTime saleDate;
  final List<SaleItem> items;
  final String? productNames; // Concatenated names for list view
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sale({
    this.id,
    required this.invoiceId,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    this.discount = 0.0,
    required this.paidAmount,
    this.paymentMethod = 'cash',
    required this.saleDate,
    required this.items,
    this.productNames,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get dueAmount {
    final due = totalAmount - paidAmount;
    return due > 0 ? due : 0.0;
  }

  double get totalProfit => items.fold(0.0, (sum, item) => sum + item.profit);

  @override
  List<Object?> get props => [
        id,
        invoiceId,
        customerId,
        customerName,
        totalAmount,
        discount,
        paidAmount,
        paymentMethod,
        saleDate,
        items,
        productNames,
        notes,
        createdAt,
        updatedAt,
      ];
}
