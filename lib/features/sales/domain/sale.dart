import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final String id;
  final String saleId;
  final String productId;
  final String productName; // Denormalized for display
  final int quantity;
  final double unitPrice;
  final double subTotal;

  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subTotal,
  });

  @override
  List<Object?> get props => [id, saleId, productId, productName, quantity, unitPrice, subTotal];
}

class Sale extends Equatable {
  final String id;
  final String invoiceId;
  final String? customerId;
  final String? customerName; // Optional display name
  final double totalAmount;
  final double discount;
  final double paidAmount;
  final String paymentMethod;
  final DateTime saleDate;
  final List<SaleItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sale({
    required this.id,
    required this.invoiceId,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    this.discount = 0.0,
    required this.paidAmount,
    this.paymentMethod = 'cash',
    required this.saleDate,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

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
        createdAt,
        updatedAt,
      ];
}
