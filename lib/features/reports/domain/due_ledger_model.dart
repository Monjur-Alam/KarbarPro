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

class CustomerTransaction extends Equatable {
  final int? id;
  final int customerId;
  final String transactionType; // 'sale' or 'payment'
  final double amount;
  final double balanceAfter;
  final String? description;
  final DateTime transactionDate;

  const CustomerTransaction({
    this.id,
    required this.customerId,
    required this.transactionType,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.transactionDate,
  });

  factory CustomerTransaction.fromMap(Map<String, dynamic> map) {
    return CustomerTransaction(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      transactionType: map['transaction_type'] as String,
      amount: (map['amount'] as num).toDouble(),
      balanceAfter: (map['balance_after_transaction'] as num).toDouble(),
      description: map['description'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
    );
  }

  @override
  List<Object?> get props => [id, customerId, transactionType, amount, balanceAfter, description, transactionDate];
}
