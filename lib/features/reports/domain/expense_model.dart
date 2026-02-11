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
