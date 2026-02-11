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
    final db = await _dbHelper.database;
    return await db.insert(DatabaseConstants.tableExpenses, {
      DatabaseConstants.colCategory: expense.category,
      DatabaseConstants.colAmount: expense.amount,
      DatabaseConstants.colDescription: expense.description,
      DatabaseConstants.colExpenseDate: expense.expenseDate.toIso8601String(),
      DatabaseConstants.colPaymentMethod: expense.paymentMethod,
      DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
      DatabaseConstants.colIsSynced: 0,
    });
  }

  // --- Due Ledger ---
  Future<List<CustomerDue>> getDueCustomers() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colCurrentCreditBalance} > 0',
      orderBy: '${DatabaseConstants.colCurrentCreditBalance} DESC',
    );
    return result.map((m) => CustomerDue.fromMap(m)).toList();
  }
}
