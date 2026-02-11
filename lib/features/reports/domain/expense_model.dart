import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final int? id;
  final String category;
  final double amount;
  final String? description;
  final DateTime expenseDate;
  final String? paymentMethod;

  const Expense({
    this.id,
    required this.category,
    required this.amount,
    this.description,
    required this.expenseDate,
    this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'description': description,
      'expense_date': expenseDate.toIso8601String(),
      'payment_method': paymentMethod,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      expenseDate: DateTime.parse(map['expense_date'] as String),
      paymentMethod: map['payment_method'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, category, amount, description, expenseDate, paymentMethod];
}

class ShopTransaction extends Equatable {
  final int? id;
  final String transactionType; // 'income' or 'expense'
  final double amount;
  final double balanceAfter;
  final String? category;
  final int? categoryId; // Added for version 4
  final String? description;
  final DateTime transactionDate;

  const ShopTransaction({
    this.id,
    required this.transactionType,
    required this.amount,
    required this.balanceAfter,
    this.category,
    this.categoryId,
    this.description,
    required this.transactionDate,
  });

  factory ShopTransaction.fromMap(Map<String, dynamic> map) {
    return ShopTransaction(
      id: map['id'] as int?,
      transactionType: map['transaction_type'] as String,
      amount: (map['amount'] as num).toDouble(),
      balanceAfter: (map['balance_after_transaction'] as num).toDouble(),
      category: map['category'] as String?,
      categoryId: map['category_id'] as int?,
      description: map['description'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
    );
  }

  @override
  List<Object?> get props => [id, transactionType, amount, balanceAfter, category, categoryId, description, transactionDate];
}

class KhorochCategory extends Equatable {
  final int? id;
  final String name;
  final String transactionType; // 'income' or 'expense'
  final bool isActive;

  const KhorochCategory({
    this.id,
    required this.name,
    required this.transactionType,
    this.isActive = true,
  });

  factory KhorochCategory.fromMap(Map<String, dynamic> map) {
    return KhorochCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      transactionType: map['transaction_type'] as String,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'transaction_type': transactionType,
      'is_active': isActive ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [id, name, transactionType, isActive];
}
