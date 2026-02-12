import 'package:equatable/equatable.dart';

class CustomerDue extends Equatable {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final String type; // 'customer' or 'supplier'
  final double currentCreditBalance;
  final double totalCredit;
  final double totalPaid;
  final double totalPurchases;
  final DateTime? lastTransactionDate;

  const CustomerDue({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    required this.type,
    required this.currentCreditBalance,
    required this.totalCredit,
    required this.totalPaid,
    required this.totalPurchases,
    this.lastTransactionDate,
  });

  factory CustomerDue.fromMap(Map<String, dynamic> map) {
    return CustomerDue(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      type: map['type'] as String? ?? 'customer',
      currentCreditBalance: (map['current_credit_balance'] as num).toDouble(),
      totalCredit: (map['total_credit'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0.0,
      totalPurchases: (map['total_purchases'] as num).toDouble(),
      lastTransactionDate: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        address,
        notes,
        type,
        currentCreditBalance,
        totalCredit,
        totalPaid,
        totalPurchases,
        lastTransactionDate
      ];
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
