import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../domain/sale.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper;

  SalesRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<void> createSale(Sale sale) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Insert Sale record
      final saleId = await txn.insert(
        DatabaseConstants.tableSales,
        {
          DatabaseConstants.colInvoiceNumber: sale.invoiceId,
          DatabaseConstants.colCustomerId: sale.customerId,
          DatabaseConstants.colPaymentType: sale.paymentMethod,
          DatabaseConstants.colSubtotal: sale.totalAmount + sale.discount,
          DatabaseConstants.colDiscount: sale.discount,
          DatabaseConstants.colTotalAmount: sale.totalAmount,
          DatabaseConstants.colTotalProfit: _calculateTotalProfit(sale),
          DatabaseConstants.colPaidAmount: sale.paidAmount,
          DatabaseConstants.colDueAmount: _calculateDueAmount(sale),
          DatabaseConstants.colPaymentStatus: _determinePaymentStatus(sale),
          DatabaseConstants.colSaleDate: sale.saleDate.toIso8601String(),
          DatabaseConstants.colNotes: sale.notes,
          DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
          DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
          DatabaseConstants.colIsSynced: 0,
        },
      );

      // 2. Process Sale Items and Update Stock
      for (final item in sale.items) {
        await txn.insert(
          DatabaseConstants.tableSaleItems,
          {
            DatabaseConstants.colSaleId: saleId,
            DatabaseConstants.colProductId: item.productId,
            DatabaseConstants.colProductName: item.productName,
            DatabaseConstants.colQuantity: item.quantity,
            DatabaseConstants.colUnitPrice: item.unitPrice,
            DatabaseConstants.colPurchasePrice: item.purchasePrice,
            DatabaseConstants.colTotalPrice: item.subTotal,
            DatabaseConstants.colProfit: item.profit,
            DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
          },
        );

        // Update Product Stock (Decrement)
        await txn.execute('''
          UPDATE ${DatabaseConstants.tableProducts} 
          SET ${DatabaseConstants.colCurrentStock} = ${DatabaseConstants.colCurrentStock} - ?,
              ${DatabaseConstants.colUpdatedAt} = ?,
              ${DatabaseConstants.colIsSynced} = 0
          WHERE ${DatabaseConstants.colId} = ?
        ''', [item.quantity, DateTime.now().toIso8601String(), item.productId]);
      }

      // 3. If Customer is involved, update their metrics
      if (sale.customerId != null) {
        final dueAmount = _calculateDueAmount(sale);
        
        // Update Customer Balance and Total Purchases
        await txn.execute('''
          UPDATE ${DatabaseConstants.tableCustomers} 
          SET ${DatabaseConstants.colCurrentCreditBalance} = ${DatabaseConstants.colCurrentCreditBalance} + ?,
              ${DatabaseConstants.colTotalPurchases} = ${DatabaseConstants.colTotalPurchases} + ?,
              ${DatabaseConstants.colUpdatedAt} = ?,
              ${DatabaseConstants.colIsSynced} = 0
          WHERE ${DatabaseConstants.colId} = ?
        ''', [dueAmount, sale.totalAmount, DateTime.now().toIso8601String(), sale.customerId]);

        // If it's a partial payment, log the credit payment
        if (sale.paidAmount > 0 && dueAmount > 0) {
          await txn.insert(DatabaseConstants.tableCreditPayments, {
            DatabaseConstants.colSaleId: saleId,
            DatabaseConstants.colCustomerId: sale.customerId,
            DatabaseConstants.colAmount: sale.paidAmount,
            DatabaseConstants.colPaymentMethod: sale.paymentMethod,
            DatabaseConstants.colPaymentDate: sale.saleDate.toIso8601String(),
            DatabaseConstants.colNotes: 'পণ্য বিক্রয়ের সময় আংশিক পরিশোধ',
            DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
            DatabaseConstants.colIsSynced: 0,
          });
        }

        // Log the transaction in Customer Transactions (Ledger History)
        final customerResult = await txn.query(
          DatabaseConstants.tableCustomers,
          columns: [DatabaseConstants.colCurrentCreditBalance],
          where: '${DatabaseConstants.colId} = ?',
          whereArgs: [sale.customerId],
        );
        final currentBalance = (customerResult.first[DatabaseConstants.colCurrentCreditBalance] as num).toDouble();

        String productDetails = sale.items.map((i) => '${i.productName} (${i.quantity})').join(', ');
        
        await txn.insert(DatabaseConstants.tableCustomerTransactions, {
          DatabaseConstants.colCustomerId: sale.customerId,
          DatabaseConstants.colTransactionType: 'sale',
          DatabaseConstants.colAmount: dueAmount, // Amount added to debt
          DatabaseConstants.colBalanceAfter: currentBalance,
          DatabaseConstants.colDescription: 'Invoice: ${sale.invoiceId}\nProducts: $productDetails',
          DatabaseConstants.colTransactionDate: sale.saleDate.toIso8601String(),
          DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
          DatabaseConstants.colIsSynced: 0,
        });
      }
    });
  }

  double _calculateTotalProfit(Sale sale) {
    return sale.items.fold(0.0, (sum, item) => sum + item.profit);
  }

  double _calculateDueAmount(Sale sale) {
    final due = sale.totalAmount - sale.paidAmount;
    return due > 0 ? due : 0.0;
  }

  String _determinePaymentStatus(Sale sale) {
    final due = _calculateDueAmount(sale);
    if (due <= 0) return 'paid';
    if (sale.paidAmount <= 0) return 'unpaid';
    return 'partial';
  }

  Future<double> getTodayTotalSales() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery('''
      SELECT SUM(${DatabaseConstants.colTotalAmount}) as total 
      FROM ${DatabaseConstants.tableSales} 
      WHERE date(${DatabaseConstants.colSaleDate}) = date(?)
    ''', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Sale>> getSales() async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableSales,
      orderBy: '${DatabaseConstants.colSaleDate} DESC',
    );

    return List.generate(maps.length, (i) {
      return Sale(
        id: maps[i][DatabaseConstants.colId],
        invoiceId: maps[i][DatabaseConstants.colInvoiceNumber],
        customerId: maps[i][DatabaseConstants.colCustomerId] as int?,
        totalAmount: (maps[i][DatabaseConstants.colTotalAmount] as num).toDouble(),
        discount: (maps[i][DatabaseConstants.colDiscount] as num).toDouble(),
        paidAmount: (maps[i][DatabaseConstants.colPaidAmount] as num).toDouble(),
        paymentMethod: maps[i][DatabaseConstants.colPaymentType],
        saleDate: DateTime.parse(maps[i][DatabaseConstants.colSaleDate]),
        createdAt: DateTime.parse(maps[i][DatabaseConstants.colCreatedAt]),
        updatedAt: DateTime.parse(maps[i][DatabaseConstants.colUpdatedAt]),
        items: [], // Fetch items lazily if needed
      );
    });
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT 
        s.*,
        c.${DatabaseConstants.colName} as customer_name
      FROM ${DatabaseConstants.tableSales} s
      LEFT JOIN ${DatabaseConstants.tableCustomers} c ON s.${DatabaseConstants.colCustomerId} = c.${DatabaseConstants.colId}
      WHERE s.${DatabaseConstants.colId} = ?
    ''', [id]);

    if (result.isEmpty) return null;

    final row = result.first;
    
    // Fetch Items
    final List<Map<String, dynamic>> itemMaps = await db.query(
      DatabaseConstants.tableSaleItems,
      where: '${DatabaseConstants.colSaleId} = ?',
      whereArgs: [id],
    );

    final items = itemMaps.map((m) => SaleItem(
      productId: m[DatabaseConstants.colProductId] as int,
      productName: m[DatabaseConstants.colProductName],
      quantity: (m[DatabaseConstants.colQuantity] as num).toInt(),
      unitPrice: (m[DatabaseConstants.colUnitPrice] as num).toDouble(),
      purchasePrice: (m[DatabaseConstants.colPurchasePrice] as num).toDouble(),
      subTotal: (m[DatabaseConstants.colTotalPrice] as num).toDouble(),
    )).toList();

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
      items: items,
      notes: row[DatabaseConstants.colNotes] as String?,
      createdAt: DateTime.parse(row[DatabaseConstants.colCreatedAt] as String),
      updatedAt: DateTime.parse(row[DatabaseConstants.colUpdatedAt] as String),
    );
  }

  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      final sale = await getSaleById(saleId);
      if (sale == null) return;

      // 1. Restore Product Stock
      for (final item in sale.items) {
        await txn.execute('''
          UPDATE ${DatabaseConstants.tableProducts} 
          SET ${DatabaseConstants.colCurrentStock} = ${DatabaseConstants.colCurrentStock} + ?,
              ${DatabaseConstants.colIsSynced} = 0
          WHERE ${DatabaseConstants.colId} = ?
        ''', [item.quantity, item.productId]);
      }

      // 2. Update Customer Balance (if applicable)
      if (sale.customerId != null) {
        final dueAmount = _calculateDueAmount(sale);
        await txn.execute('''
          UPDATE ${DatabaseConstants.tableCustomers} 
          SET ${DatabaseConstants.colCurrentCreditBalance} = ${DatabaseConstants.colCurrentCreditBalance} - ?,
              ${DatabaseConstants.colTotalPurchases} = ${DatabaseConstants.colTotalPurchases} - ?,
              ${DatabaseConstants.colIsSynced} = 0
          WHERE ${DatabaseConstants.colId} = ?
        ''', [dueAmount, sale.totalAmount, sale.customerId]);
        
        // Remove credit payments records for this sale
        await txn.delete(
          DatabaseConstants.tableCreditPayments,
          where: '${DatabaseConstants.colSaleId} = ?',
          whereArgs: [saleId],
        );
      }

      // 3. Delete Sale and Items
      await txn.delete(DatabaseConstants.tableSaleItems, where: '${DatabaseConstants.colSaleId} = ?', whereArgs: [saleId]);
      await txn.delete(DatabaseConstants.tableSales, where: '${DatabaseConstants.colId} = ?', whereArgs: [saleId]);
    });
  }
}
