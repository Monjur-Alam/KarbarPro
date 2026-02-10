import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final double currentCreditBalance;
  final double totalPurchases;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.currentCreditBalance = 0.0,
    this.totalPurchases = 0.0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? currentCreditBalance,
    double? totalPurchases,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      currentCreditBalance: currentCreditBalance ?? this.currentCreditBalance,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email, address, currentCreditBalance, totalPurchases, isActive, createdAt, updatedAt];
}
