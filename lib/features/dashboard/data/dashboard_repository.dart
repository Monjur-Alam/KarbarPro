import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/database_constants.dart';

class DashboardSummary {
  final int totalSalesToday;
  final double totalAmountToday;
  final double totalProfitToday;
  final List<Map<String, dynamic>> recentSales;
  final List<Map<String, dynamic>> lowStockProducts;
  final double mainBalance;
  final double totalReceivable;
  final double totalCollected;
  final double totalPayable;
  final double totalPaid;
  final double totalExpense;
  final double totalSalesCash;
  final double totalSalesCredit;
  final double paidToSupplierInPeriod;
  final double dueCollectionInPeriod;
  final double totalManualIncomeInPeriod;
  final double totalManualExpenseInPeriod;

  DashboardSummary({
    required this.totalSalesToday,
    required this.totalAmountToday,
    required this.totalProfitToday,
    required this.recentSales,
    required this.lowStockProducts,
    required this.mainBalance,
    required this.totalReceivable,
    required this.totalCollected,
    required this.totalPayable,
    required this.totalPaid,
    required this.totalExpense,
    required this.totalSalesCash,
    required this.totalSalesCredit,
    required this.paidToSupplierInPeriod,
    required this.dueCollectionInPeriod,
    required this.totalManualIncomeInPeriod,
    required this.totalManualExpenseInPeriod,
  });
}

class DashboardRepository {
  final DatabaseHelper _dbHelper;

  DashboardRepository(this._dbHelper);

  Future<DashboardSummary> getDashboardSummary({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now();
    
    final startDateStr = DateTime(start.year, start.month, start.day, 0, 0, 0).toIso8601String();
    final endDateStr = DateTime(end.year, end.month, end.day, 23, 59, 59, 999).toIso8601String();
    
    final db = await _dbHelper.database;

    // 1. Total Sales and Profit in Period
    final salesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as count, 
        SUM(${DatabaseConstants.colTotalAmount}) as total_amount, 
        SUM(${DatabaseConstants.colTotalProfit}) as total_profit,
        SUM(CASE WHEN ${DatabaseConstants.colPaymentType} = 'cash' THEN ${DatabaseConstants.colTotalAmount} ELSE 0 END) as cash_sales,
        SUM(CASE WHEN ${DatabaseConstants.colPaymentType} = 'credit' THEN ${DatabaseConstants.colTotalAmount} ELSE 0 END) as credit_sales
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.colSaleDate} BETWEEN ? AND ?
    ''', [startDateStr, endDateStr]);

    final totalSalesInPeriod = (salesResult.first['count'] as num?)?.toInt() ?? 0;
    final totalAmountInPeriod = (salesResult.first['total_amount'] as num?)?.toDouble() ?? 0.0;
    final totalProfitInPeriod = (salesResult.first['total_profit'] as num?)?.toDouble() ?? 0.0;
    final totalSalesCash = (salesResult.first['cash_sales'] as num?)?.toDouble() ?? 0.0;
    final totalSalesCredit = (salesResult.first['credit_sales'] as num?)?.toDouble() ?? 0.0;

    // 2. Recent 10 Sales (Global)
    final recentSales = await db.query(
      DatabaseConstants.tableSales,
      orderBy: '${DatabaseConstants.colSaleDate} DESC',
      limit: 10,
    );

    // 3. Low Stock Alerts (Global)
    final lowStockResult = await db.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.colCurrentStock} <= ${DatabaseConstants.colMinStockAlert} AND ${DatabaseConstants.colIsActive} = 1',
    );

    // 4. Shop Main Balance (Global)
    final balanceResult = await db.rawQuery('''
      SELECT ${DatabaseConstants.colBalanceAfter} 
      FROM ${DatabaseConstants.tableShopTransactions} 
      ORDER BY ${DatabaseConstants.colId} DESC LIMIT 1
    ''');
    final mainBalance = (balanceResult.isNotEmpty) 
        ? (balanceResult.first[DatabaseConstants.colBalanceAfter] as num).toDouble() 
        : 0.0;

    // 5. Bakir Khata Summary (Global totals)
    final receivableTotalResult = await db.rawQuery('''
      SELECT 
        SUM(${DatabaseConstants.colCurrentCreditBalance}) as totalReceivable,
        SUM(${DatabaseConstants.colTotalPaid}) as totalCollected
      FROM ${DatabaseConstants.tableCustomers}
      WHERE ${DatabaseConstants.colCustomerType} = 'customer' AND ${DatabaseConstants.colDeletedAt} IS NULL
    ''');

    final payableTotalResult = await db.rawQuery('''
      SELECT 
        SUM(ABS(${DatabaseConstants.colCurrentCreditBalance})) as totalPayable,
        SUM(${DatabaseConstants.colTotalPaid}) as totalPaid
      FROM ${DatabaseConstants.tableCustomers}
      WHERE ${DatabaseConstants.colCustomerType} = 'supplier' AND ${DatabaseConstants.colDeletedAt} IS NULL
    ''');

    // 6. Period-based Payment Tracking (Collections & Supplier Payments)
    final dueCollectionResult = await db.rawQuery('''
      SELECT SUM(${DatabaseConstants.colAmount}) as amount
      FROM ${DatabaseConstants.tableCustomerTransactions}
      WHERE ${DatabaseConstants.colTransactionType} IN ('payment', 'payment_received')
      AND ${DatabaseConstants.colTransactionDate} BETWEEN ? AND ?
      AND ${DatabaseConstants.colCustomerId} IN (SELECT ${DatabaseConstants.colId} FROM ${DatabaseConstants.tableCustomers} WHERE ${DatabaseConstants.colCustomerType} = 'customer')
    ''', [startDateStr, endDateStr]);
    final dueCollectionInPeriod = (dueCollectionResult.first['amount'] as num?)?.toDouble() ?? 0.0;

    final supplierPaidResult = await db.rawQuery('''
      SELECT SUM(${DatabaseConstants.colAmount}) as amount
      FROM ${DatabaseConstants.tableCustomerTransactions}
      WHERE ${DatabaseConstants.colTransactionType} IN ('payment', 'payment_received')
      AND ${DatabaseConstants.colTransactionDate} BETWEEN ? AND ?
      AND ${DatabaseConstants.colCustomerId} IN (SELECT ${DatabaseConstants.colId} FROM ${DatabaseConstants.tableCustomers} WHERE ${DatabaseConstants.colCustomerType} = 'supplier')
    ''', [startDateStr, endDateStr]);
    final paidToSupplierInPeriod = (supplierPaidResult.first['amount'] as num?)?.toDouble() ?? 0.0;

    // 7. Manual Income and Expense in Period from Shop Transactions
    final manualSummaryResult = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN ${DatabaseConstants.colTransactionType} = 'income' THEN ${DatabaseConstants.colAmount} ELSE 0 END) as total_income,
        SUM(CASE WHEN ${DatabaseConstants.colTransactionType} = 'expense' THEN ${DatabaseConstants.colAmount} ELSE 0 END) as total_expense
      FROM ${DatabaseConstants.tableShopTransactions}
      WHERE ${DatabaseConstants.colTransactionSource} = 'manual_khoroch'
      AND ${DatabaseConstants.colDeletedAt} IS NULL
      AND ${DatabaseConstants.colTransactionDate} BETWEEN ? AND ?
    ''', [startDateStr, endDateStr]);
    
    final totalManualIncomeInPeriod = (manualSummaryResult.first['total_income'] as num?)?.toDouble() ?? 0.0;
    final totalManualExpenseInPeriod = (manualSummaryResult.first['total_expense'] as num?)?.toDouble() ?? 0.0;

    // 8. Total Overhead Expenses in Period (Legacy/Overlap - keeping for backward compatibility if needed)
    final expenseResult = await db.rawQuery('''
      SELECT SUM(${DatabaseConstants.colAmount}) as total_expense
      FROM ${DatabaseConstants.tableExpenses}
      WHERE ${DatabaseConstants.colExpenseDate} BETWEEN ? AND ?
    ''', [startDateStr, endDateStr]);
    final totalExpenseInPeriod = (expenseResult.first['total_expense'] as num?)?.toDouble() ?? 0.0;

    return DashboardSummary(
      totalSalesToday: totalSalesInPeriod,
      totalAmountToday: totalAmountInPeriod,
      totalProfitToday: totalProfitInPeriod,
      recentSales: recentSales,
      lowStockProducts: lowStockResult,
      mainBalance: mainBalance,
      totalReceivable: (receivableTotalResult.first['totalReceivable'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (receivableTotalResult.first['totalCollected'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (payableTotalResult.first['totalPayable'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (payableTotalResult.first['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalExpense: totalExpenseInPeriod > 0 ? totalExpenseInPeriod : totalManualExpenseInPeriod,
      totalSalesCash: totalSalesCash,
      totalSalesCredit: totalSalesCredit,
      paidToSupplierInPeriod: paidToSupplierInPeriod,
      dueCollectionInPeriod: dueCollectionInPeriod,
      totalManualIncomeInPeriod: totalManualIncomeInPeriod,
      totalManualExpenseInPeriod: totalManualExpenseInPeriod,
    );
  }
}
