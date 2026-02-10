import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../domain/sale.dart';
import 'package:sqflite/sqflite.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper;

  SalesRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<void> createSale(Sale sale) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Insert Sale
      await txn.insert(
        DatabaseConstants.tableSales,
        {
          DatabaseConstants.colId: sale.id,
          DatabaseConstants.colInvoiceId: sale.invoiceId,
          DatabaseConstants.colCustomerId: sale.customerId,
          DatabaseConstants.colTotalAmount: sale.totalAmount,
          DatabaseConstants.colDiscount: sale.discount,
          DatabaseConstants.colPaidAmount: sale.paidAmount,
          DatabaseConstants.colPaymentMethod: sale.paymentMethod,
          DatabaseConstants.colSaleDate: sale.saleDate.toIso8601String(),
          DatabaseConstants.colCreatedAt: sale.createdAt.toIso8601String(),
          DatabaseConstants.colUpdatedAt: sale.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert Sale Items
      for (final item in sale.items) {
        await txn.insert(
          DatabaseConstants.tableSaleItems,
          {
            DatabaseConstants.colId: item.id,
            DatabaseConstants.colSaleId: sale.id,
            DatabaseConstants.colProductId: item.productId,
            DatabaseConstants.colQuantity: item.quantity,
            DatabaseConstants.colUnitPrice: item.unitPrice,
            DatabaseConstants.colSubTotal: item.subTotal,
            DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 3. Update Product Stock (Decrement)
        // We need to fetch current stock logic or handle it via a separate query
        await txn.rawUpdate(
          'UPDATE ${DatabaseConstants.tableProducts} SET ${DatabaseConstants.colStockQuantity} = ${DatabaseConstants.colStockQuantity} - ? WHERE ${DatabaseConstants.colId} = ?',
          [item.quantity, item.productId],
        );
      }
    });
  }

  Future<List<Sale>> getSales() async {
    final db = await _dbHelper.database;
    // Simple join to get basic sale info
    // For full items list, we'd need separate queries or a complex join mapping
    
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableSales,
      orderBy: '${DatabaseConstants.colSaleDate} DESC',
    );

    return List.generate(maps.length, (i) {
      return Sale(
        id: maps[i][DatabaseConstants.colId],
        invoiceId: maps[i][DatabaseConstants.colInvoiceId],
        customerId: maps[i][DatabaseConstants.colCustomerId],
        totalAmount: maps[i][DatabaseConstants.colTotalAmount],
        discount: maps[i][DatabaseConstants.colDiscount],
        paidAmount: maps[i][DatabaseConstants.colPaidAmount],
        paymentMethod: maps[i][DatabaseConstants.colPaymentMethod],
        saleDate: DateTime.parse(maps[i][DatabaseConstants.colSaleDate]),
        createdAt: DateTime.parse(maps[i][DatabaseConstants.colCreatedAt]),
        updatedAt: DateTime.parse(maps[i][DatabaseConstants.colUpdatedAt]),
        items: [], // Fetch items lazily if needed or mostly for summary
      );
    });
  }
}
