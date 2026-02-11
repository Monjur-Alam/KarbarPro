import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/constants/database_constants.dart';
import '../domain/report_models.dart';
import '../domain/expense_model.dart';
import '../domain/due_ledger_model.dart';
import '../../sales/domain/sale.dart';

class ReportRepository {
  final DatabaseHelper _dbHelper;

  ReportRepository({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  Future<SummaryStats> getSummaryStats(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(${DatabaseConstants.colTotalAmount}) as revenue,
        SUM(${DatabaseConstants.colTotalProfit}) as profit,
        AVG(${DatabaseConstants.colTotalAmount}) as average
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.colSaleDate} BETWEEN ? AND ?
    ''', [startDate, endDate]);

    if (result.isEmpty || result.first['count'] == 0) {
      return const SummaryStats(
        salesCount: 0,
        totalRevenue: 0,
        totalProfit: 0,
        averageSale: 0,
      );
    }

    final row = result.first;
    
    // Comparison logic for Growth (get previous period)
    final duration = end.difference(start);
    final prevStart = start.subtract(duration).toIso8601String();
    final prevEnd = start.toIso8601String();
    
    final prevResult = await db.rawQuery('''
      SELECT SUM(${DatabaseConstants.colTotalAmount}) as revenue
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.colSaleDate} BETWEEN ? AND ?
    ''', [prevStart, prevEnd]);
    
    double? prevRevenue;
    if (prevResult.isNotEmpty && prevResult.first['revenue'] != null) {
      prevRevenue = (prevResult.first['revenue'] as num).toDouble();
    }

    return SummaryStats(
      salesCount: row['count'] as int,
      totalRevenue: (row['revenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (row['profit'] as num?)?.toDouble() ?? 0.0,
      averageSale: (row['average'] as num?)?.toDouble() ?? 0.0,
      previousRevenue: prevRevenue,
    );
  }

  Future<List<ProductReportItem>> getTopProducts(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final result = await db.rawQuery('''
      SELECT 
        si.${DatabaseConstants.colProductId} as id,
        si.${DatabaseConstants.colProductName} as name,
        SUM(si.${DatabaseConstants.colQuantity}) as qty,
        SUM(si.${DatabaseConstants.colTotalPrice}) as revenue,
        SUM(si.${DatabaseConstants.colProfit}) as profit
      FROM ${DatabaseConstants.tableSaleItems} si
      JOIN ${DatabaseConstants.tableSales} s ON si.${DatabaseConstants.colSaleId} = s.${DatabaseConstants.colId}
      WHERE s.${DatabaseConstants.colSaleDate} BETWEEN ? AND ?
      GROUP BY si.${DatabaseConstants.colProductId}
      ORDER BY qty DESC
      LIMIT 10
    ''', [startDate, endDate]);

    return result.map((row) => ProductReportItem(
      productId: row['id'] as int,
      productName: row['name'] as String,
      quantitySold: row['qty'] as int,
      totalRevenue: (row['revenue'] as num).toDouble(),
      totalProfit: (row['profit'] as num).toDouble(),
    )).toList();
  }

  Future<List<DailyTrendPoint>> getDailyTrend(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final result = await db.rawQuery('''
      SELECT 
        date(${DatabaseConstants.colSaleDate}) as day,
        SUM(${DatabaseConstants.colTotalAmount}) as revenue,
        SUM(${DatabaseConstants.colTotalProfit}) as profit
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.colSaleDate} BETWEEN ? AND ?
      GROUP BY day
      ORDER BY day ASC
    ''', [startDate, endDate]);

    return result.map((row) => DailyTrendPoint(
      date: DateTime.parse(row['day'] as String),
      revenue: (row['revenue'] as num).toDouble(),
      profit: (row['profit'] as num).toDouble(),
    )).toList();
  }

  Future<List<PaymentTypeSummary>> getPaymentSummary(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final result = await db.rawQuery('''
      SELECT 
        ${DatabaseConstants.colPaymentType} as type,
        COUNT(*) as count,
        SUM(${DatabaseConstants.colTotalAmount}) as revenue
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.colSaleDate} BETWEEN ? AND ?
      GROUP BY type
    ''', [startDate, endDate]);

    return result.map((row) => PaymentTypeSummary(
      paymentType: row['type'] as String,
      count: row['count'] as int,
      revenue: (row['revenue'] as num).toDouble(),
    )).toList();
  }

  Future<List<Sale>> getFilteredSales(DateTime start, DateTime end, {String? paymentType}) async {
    final db = await _dbHelper.database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    String whereClause = 'WHERE s.${DatabaseConstants.colSaleDate} BETWEEN ? AND ?';
    List<dynamic> params = [startDate, endDate];

    if (paymentType != null && paymentType != 'all') {
      whereClause += ' AND s.${DatabaseConstants.colPaymentType} = ?';
      params.add(paymentType);
    }

    final result = await db.rawQuery('''
      SELECT 
        s.*,
        c.${DatabaseConstants.colName} as customer_name
      FROM ${DatabaseConstants.tableSales} s
      LEFT JOIN ${DatabaseConstants.tableCustomers} c ON s.${DatabaseConstants.colCustomerId} = c.${DatabaseConstants.colId}
      $whereClause
      ORDER BY s.${DatabaseConstants.colSaleDate} DESC
    ''', params);

    return result.map((row) {
      // This mapping needs to match how Sale objects are constructed elsewhere
      // Assuming existing fromMap logic in Sale model or handled here
      return _mapRowToSale(row);
    }).toList();
  }

  Sale _mapRowToSale(Map<String, dynamic> row) {
    return Sale(
      id: row[DatabaseConstants.colId] as int,
      invoiceId: row[DatabaseConstants.colInvoiceNumber] as String,
      customerId: row[DatabaseConstants.colCustomerId] as int?,
      customerName: row['customer_name'] as String?,
      totalAmount: (row[DatabaseConstants.colTotalAmount] as num).toDouble(),
      discount: (row[DatabaseConstants.colDiscount] as num).toDouble(),
      paidAmount: (row[DatabaseConstants.colPaidAmount] as num).toDouble(),
      paymentMethod: row[DatabaseConstants.colPaymentType] as String,
      saleDate: DateTime.parse(row[DatabaseConstants.colSaleDate] as String),
      items: [], // Items are lazy loaded or fetched separately if needed for report detail
      createdAt: DateTime.parse(row[DatabaseConstants.colCreatedAt] as String),
      updatedAt: DateTime.parse(row[DatabaseConstants.colUpdatedAt] as String),
    );
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT * FROM ${DatabaseConstants.tableProducts} 
      WHERE ${DatabaseConstants.colCurrentStock} <= ${DatabaseConstants.colMinStockAlert}
    ''');
  }

  // --- Expense Management ---
  Future<List<Expense>> getExpenses(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseConstants.tableExpenses,
      where: '${DatabaseConstants.colExpenseDate} BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: '${DatabaseConstants.colExpenseDate} DESC',
    );
    return result.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> addExpense(Expense expense) async {
    return await addShopTransaction(
      type: 'expense',
      amount: expense.amount,
      category: expense.category,
      description: expense.description,
      date: expense.expenseDate,
    );
  }

  // --- Shop Balance & Transactions ---
  Future<int> addShopTransaction({
    required String type, // 'income' or 'expense'
    required double amount,
    String? category,
    String? description,
    DateTime? date,
    String source = 'manual_khoroch',
  }) async {
    final db = await _dbHelper.database;
    final transactionDate = date ?? DateTime.now();

    return await db.transaction((txn) async {
      // Get current balance
      final result = await txn.rawQuery('''
        SELECT ${DatabaseConstants.colBalanceAfter} 
        FROM ${DatabaseConstants.tableShopTransactions} 
        ORDER BY ${DatabaseConstants.colId} DESC LIMIT 1
      ''');
      
      double currentBalance = 0;
      if (result.isNotEmpty) {
        currentBalance = (result.first[DatabaseConstants.colBalanceAfter] as num).toDouble();
      }

      double newBalance = type == 'income' 
          ? currentBalance + amount 
          : currentBalance - amount;

      return await txn.insert(DatabaseConstants.tableShopTransactions, {
        DatabaseConstants.colTransactionType: type,
        DatabaseConstants.colAmount: amount,
        DatabaseConstants.colBalanceAfter: newBalance,
        DatabaseConstants.colCategory: category,
        DatabaseConstants.colDescription: description,
        DatabaseConstants.colTransactionDate: transactionDate.toIso8601String(),
        DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.colTransactionSource: source,
        DatabaseConstants.colIsSynced: 0,
      });
    });
  }

  Future<double> getShopMainBalance() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT ${DatabaseConstants.colBalanceAfter} 
      FROM ${DatabaseConstants.tableShopTransactions} 
      ORDER BY ${DatabaseConstants.colId} DESC LIMIT 1
    ''');
    
    if (result.isEmpty) return 0.0;
    return (result.first[DatabaseConstants.colBalanceAfter] as num).toDouble();
  }

  Future<List<ShopTransaction>> getShopTransactions(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseConstants.tableShopTransactions,
      where: '${DatabaseConstants.colTransactionDate} BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: '${DatabaseConstants.colTransactionDate} DESC',
    );
    return result.map((m) => ShopTransaction.fromMap(m)).toList();
  }

  // Get only manual khoroch transactions (exclude automatic sales/payments)
  Future<List<ShopTransaction>> getManualKhorochTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await _dbHelper.database;
    
    String whereClause = "${DatabaseConstants.colTransactionSource} = 'manual_khoroch'";
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause += " AND ${DatabaseConstants.colTransactionDate} BETWEEN ? AND ?";
      whereArgs.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += " AND (${DatabaseConstants.colDescription} LIKE ? OR ${DatabaseConstants.colCategory} LIKE ? OR CAST(${DatabaseConstants.colAmount} AS TEXT) LIKE ?)";
      final searchPattern = '%$searchQuery%';
      whereArgs.addAll([searchPattern, searchPattern, searchPattern]);
    }
    
    final result = await db.query(
      DatabaseConstants.tableShopTransactions,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '${DatabaseConstants.colTransactionDate} DESC',
    );
    
    return result.map((m) => ShopTransaction.fromMap(m)).toList();
  }

  // Get summary of manual khoroch transactions
  Future<Map<String, dynamic>> getManualKhorochSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    
    String whereClause = "${DatabaseConstants.colTransactionSource} = 'manual_khoroch'";
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause += " AND ${DatabaseConstants.colTransactionDate} BETWEEN ? AND ?";
      whereArgs.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN ${DatabaseConstants.colTransactionType} = 'income' THEN ${DatabaseConstants.colAmount} ELSE 0 END) as totalIncome,
        SUM(CASE WHEN ${DatabaseConstants.colTransactionType} = 'expense' THEN ${DatabaseConstants.colAmount} ELSE 0 END) as totalExpense,
        COUNT(*) as transactionCount
      FROM ${DatabaseConstants.tableShopTransactions}
      WHERE $whereClause
    ''', whereArgs.isNotEmpty ? whereArgs : null);
    
    if (result.isEmpty) {
      return {'totalIncome': 0.0, 'totalExpense': 0.0, 'transactionCount': 0};
    }
    
    final row = result.first;
    return {
      'totalIncome': (row['totalIncome'] as num?)?.toDouble() ?? 0.0,
      'totalExpense': (row['totalExpense'] as num?)?.toDouble() ?? 0.0,
      'transactionCount': (row['transactionCount'] as int?) ?? 0,
    };
  }

  // --- Due Ledger & Customer Payments ---
  Future<List<CustomerDue>> getDueCustomers() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colCurrentCreditBalance} > 0',
      orderBy: '${DatabaseConstants.colCurrentCreditBalance} DESC',
    );
    return result.map((m) => CustomerDue.fromMap(m)).toList();
  }

  Future<void> recordCustomerPayment({
    required int customerId,
    required double amount,
    String? notes,
    DateTime? date,
  }) async {
    final db = await _dbHelper.database;
    final paymentDate = date ?? DateTime.now();

    await db.transaction((txn) async {
      // 1. Update Customer Balance
      await txn.execute('''
        UPDATE ${DatabaseConstants.tableCustomers} 
        SET ${DatabaseConstants.colCurrentCreditBalance} = ${DatabaseConstants.colCurrentCreditBalance} - ?,
            ${DatabaseConstants.colUpdatedAt} = ?,
            ${DatabaseConstants.colIsSynced} = 0
        WHERE ${DatabaseConstants.colId} = ?
      ''', [amount, DateTime.now().toIso8601String(), customerId]);

      // Get new balance for history
      final customerResult = await txn.query(
        DatabaseConstants.tableCustomers,
        columns: [DatabaseConstants.colCurrentCreditBalance],
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [customerId],
      );
      final newBalance = (customerResult.first[DatabaseConstants.colCurrentCreditBalance] as num).toDouble();

      // 2. Log in credit_payments (legacy support/detailed tracking)
      await txn.insert(DatabaseConstants.tableCreditPayments, {
        DatabaseConstants.colCustomerId: customerId,
        DatabaseConstants.colAmount: amount,
        DatabaseConstants.colPaymentMethod: 'Cash',
        DatabaseConstants.colPaymentDate: paymentDate.toIso8601String(),
        DatabaseConstants.colNotes: notes,
        DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.colIsSynced: 0,
      });

      // 3. Log in customer_transactions (Ledger History)
      await txn.insert(DatabaseConstants.tableCustomerTransactions, {
        DatabaseConstants.colCustomerId: customerId,
        DatabaseConstants.colTransactionType: 'payment',
        DatabaseConstants.colAmount: amount,
        DatabaseConstants.colBalanceAfter: newBalance,
        DatabaseConstants.colDescription: notes ?? 'হালখাতা/বকেয়া পরিশোধ',
        DatabaseConstants.colTransactionDate: paymentDate.toIso8601String(),
        DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.colIsSynced: 0,
      });
      
      // 4. Optionally add to Shop Main Balance as Income
      await _addShopTransactionTxn(txn, 
        type: 'income', 
        amount: amount, 
        category: 'বকেয়া সংগ্রহ', 
        description: 'Customer Payment (ID: $customerId)', 
        date: paymentDate,
        source: 'credit_payment',
      );
    });
  }

  Future<List<CustomerTransaction>> getCustomerTransactionHistory(int customerId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseConstants.tableCustomerTransactions,
      where: '${DatabaseConstants.colCustomerId} = ?',
      whereArgs: [customerId],
      orderBy: '${DatabaseConstants.colTransactionDate} DESC',
    );
    return result.map((m) => CustomerTransaction.fromMap(m)).toList();
  }

  // Helper for adding shop transaction within existing transaction
  Future<void> _addShopTransactionTxn(Transaction txn, {
    required String type,
    required double amount,
    String? category,
    String? description,
    DateTime? date,
    String source = 'manual_khoroch',
  }) async {
    final transactionDate = date ?? DateTime.now();
    
    final result = await txn.rawQuery('''
      SELECT ${DatabaseConstants.colBalanceAfter} 
      FROM ${DatabaseConstants.tableShopTransactions} 
      ORDER BY ${DatabaseConstants.colId} DESC LIMIT 1
    ''');
    
    double currentBalance = 0;
    if (result.isNotEmpty) {
      currentBalance = (result.first[DatabaseConstants.colBalanceAfter] as num).toDouble();
    }

    double newBalance = type == 'income' 
        ? currentBalance + amount 
        : currentBalance - amount;

    await txn.insert(DatabaseConstants.tableShopTransactions, {
      DatabaseConstants.colTransactionType: type,
      DatabaseConstants.colAmount: amount,
      DatabaseConstants.colBalanceAfter: newBalance,
      DatabaseConstants.colCategory: category,
      DatabaseConstants.colDescription: description,
      DatabaseConstants.colTransactionDate: transactionDate.toIso8601String(),
      DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
      DatabaseConstants.colTransactionSource: source,
      DatabaseConstants.colIsSynced: 0,
    });
  }
  // Update existing shop transaction and recalculate all subsequent balances
  Future<void> updateShopTransaction({
    required int transactionId,
    required String type,
    required double amount,
    String? category,
    String? description,
    DateTime? date,
  }) async {
    final db = await _dbHelper.database;
    final transactionDate = date ?? DateTime.now();

    await db.transaction((txn) async {
      // Get the transaction being edited
      final oldTransResult = await txn.query(
        DatabaseConstants.tableShopTransactions,
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [transactionId],
      );

      if (oldTransResult.isEmpty) {
        throw Exception('Transaction not found');
      }

      // Get the balance before this transaction
      final prevBalanceResult = await txn.rawQuery('''
        SELECT ${DatabaseConstants.colBalanceAfter} 
        FROM ${DatabaseConstants.tableShopTransactions} 
        WHERE ${DatabaseConstants.colId} < ?
        ORDER BY ${DatabaseConstants.colId} DESC LIMIT 1
      ''', [transactionId]);

      double balanceBeforeThis = 0;
      if (prevBalanceResult.isNotEmpty) {
        balanceBeforeThis = (prevBalanceResult.first[DatabaseConstants.colBalanceAfter] as num).toDouble();
      }

      // Calculate new balance after this transaction
      double newBalanceAfter = type == 'income' 
          ? balanceBeforeThis + amount 
          : balanceBeforeThis - amount;

      // Update the transaction
      await txn.update(
        DatabaseConstants.tableShopTransactions,
        {
          DatabaseConstants.colTransactionType: type,
          DatabaseConstants.colAmount: amount,
          DatabaseConstants.colBalanceAfter: newBalanceAfter,
          DatabaseConstants.colCategory: category,
          DatabaseConstants.colDescription: description,
          DatabaseConstants.colTransactionDate: transactionDate.toIso8601String(),
          DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
          DatabaseConstants.colIsSynced: 0,
        },
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [transactionId],
      );

      // Recalculate all subsequent transactions
      await _recalculateSubsequentBalances(txn, transactionId, newBalanceAfter);
    });
  }

  // Delete shop transaction and recalculate subsequent balances
  Future<void> deleteShopTransaction(int transactionId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Get the balance before this transaction
      final prevBalanceResult = await txn.rawQuery('''
        SELECT ${DatabaseConstants.colBalanceAfter} 
        FROM ${DatabaseConstants.tableShopTransactions} 
        WHERE ${DatabaseConstants.colId} < ?
        ORDER BY ${DatabaseConstants.colId} DESC LIMIT 1
      ''', [transactionId]);

      double balanceBeforeThis = 0;
      if (prevBalanceResult.isNotEmpty) {
        balanceBeforeThis = (prevBalanceResult.first[DatabaseConstants.colBalanceAfter] as num).toDouble();
      }

      // Delete the transaction
      await txn.delete(
        DatabaseConstants.tableShopTransactions,
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [transactionId],
      );

      // Recalculate all subsequent transactions
      await _recalculateSubsequentBalances(txn, transactionId, balanceBeforeThis);
    });
  }

  // Helper to recalculate balances for all transactions after a given ID
  Future<void> _recalculateSubsequentBalances(Transaction txn, int afterId, double startingBalance) async {
    // Get all transactions after the edited/deleted one
    final subsequentTrans = await txn.query(
      DatabaseConstants.tableShopTransactions,
      where: '${DatabaseConstants.colId} > ?',
      whereArgs: [afterId],
      orderBy: '${DatabaseConstants.colId} ASC',
    );

    double runningBalance = startingBalance;

    for (final trans in subsequentTrans) {
      final type = trans[DatabaseConstants.colTransactionType] as String;
      final amount = (trans[DatabaseConstants.colAmount] as num).toDouble();
      
      runningBalance = type == 'income' 
          ? runningBalance + amount 
          : runningBalance - amount;

      await txn.update(
        DatabaseConstants.tableShopTransactions,
        {
          DatabaseConstants.colBalanceAfter: runningBalance,
          DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [trans[DatabaseConstants.colId]],
      );
    }
  }
}
