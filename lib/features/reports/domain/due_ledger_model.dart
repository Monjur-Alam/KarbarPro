import 'package:equatable/equatable.dart';

class CustomerDue extends Equatable {
  final int id;
  final String name;
  final String? phone;
  final double currentCreditBalance;
  final double totalPurchases;

  const CustomerDue({
    required this.id,
    required this.name,
    this.phone,
    required this.currentCreditBalance,
    required this.totalPurchases,
  });

  factory CustomerDue.fromMap(Map<String, dynamic> map) {
    return CustomerDue(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      currentCreditBalance: (map['current_credit_balance'] as num).toDouble(),
      totalPurchases: (map['total_purchases'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [id, name, phone, currentCreditBalance, totalPurchases];
}
