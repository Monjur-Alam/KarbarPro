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
  });
}

class DashboardRepository {
  final DatabaseHelper _dbHelper;

  DashboardRepository(this._dbHelper);

  Future<DashboardSummary> getDashboardSummary() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final db = await _dbHelper.database;

    // 1. Total Sales and Profit Today
    final salesResult = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(${DatabaseConstants.colTotalAmount}) as total_amount, 
             SUM(${DatabaseConstants.colTotalProfit}) as total_profit
      FROM ${DatabaseConstants.tableSales}
      WHERE date(${DatabaseConstants.colSaleDate}) = date(?)
    ''', [today]);

    final totalSalesToday = (salesResult.first['count'] as num?)?.toInt() ?? 0;
    final totalAmountToday = (salesResult.first['total_amount'] as num?)?.toDouble() ?? 0.0;
    final totalProfitToday = (salesResult.first['total_profit'] as num?)?.toDouble() ?? 0.0;

    // 2. Recent 5 Sales
    final recentSales = await db.query(
      DatabaseConstants.tableSales,
      orderBy: '${DatabaseConstants.colSaleDate} DESC',
      limit: 5,
    );

    // 3. Low Stock Alerts
    final lowStockResult = await db.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.colCurrentStock} <= ${DatabaseConstants.colMinStockAlert} AND ${DatabaseConstants.colIsActive} = 1',
    );

    // 4. Shop Main Balance
    final balanceResult = await db.rawQuery('''
      SELECT ${DatabaseConstants.colBalanceAfter} 
      FROM ${DatabaseConstants.tableShopTransactions} 
      ORDER BY ${DatabaseConstants.colId} DESC LIMIT 1
    ''');
    final mainBalance = (balanceResult.isNotEmpty) 
        ? (balanceResult.first[DatabaseConstants.colBalanceAfter] as num).toDouble() 
        : 0.0;

    // 5. Bakir Khata Summary
    // Total Receivable (Customers)
    final receivableResult = await db.rawQuery('''
      SELECT 
        SUM(${DatabaseConstants.colCurrentCreditBalance}) as totalReceivable,
        SUM(${DatabaseConstants.colTotalPaid}) as totalCollected
      FROM ${DatabaseConstants.tableCustomers}
      WHERE ${DatabaseConstants.colCustomerType} = 'customer' AND ${DatabaseConstants.colDeletedAt} IS NULL
    ''');

    // Total Payable (Suppliers)
    final payableResult = await db.rawQuery('''
      SELECT 
        SUM(ABS(${DatabaseConstants.colCurrentCreditBalance})) as totalPayable,
        SUM(${DatabaseConstants.colTotalPaid}) as totalPaid
      FROM ${DatabaseConstants.tableCustomers}
      WHERE ${DatabaseConstants.colCustomerType} = 'supplier' AND ${DatabaseConstants.colDeletedAt} IS NULL
    ''');

    return DashboardSummary(
      totalSalesToday: totalSalesToday,
      totalAmountToday: totalAmountToday,
      totalProfitToday: totalProfitToday,
      recentSales: recentSales,
      lowStockProducts: lowStockResult,
      mainBalance: mainBalance,
      totalReceivable: (receivableResult.first['totalReceivable'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (receivableResult.first['totalCollected'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (payableResult.first['totalPayable'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (payableResult.first['totalPaid'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
