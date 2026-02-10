import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../domain/sale.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper;

  SalesRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<void> createSale(Sale sale) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Insert Sale
      final saleId = await txn.insert(
        DatabaseConstants.tableSales,
        {
          DatabaseConstants.colInvoiceNumber: sale.invoiceId,
          DatabaseConstants.colCustomerId: sale.customerId,
          DatabaseConstants.colPaymentType: sale.paymentMethod,
          DatabaseConstants.colSubtotal: sale.totalAmount, // Map to subtotal for simplicity
          DatabaseConstants.colDiscount: sale.discount,
          DatabaseConstants.colTotalAmount: sale.totalAmount,
          DatabaseConstants.colPaidAmount: sale.paidAmount,
          DatabaseConstants.colPaymentStatus: 'paid', // Default
          DatabaseConstants.colSaleDate: sale.saleDate.toIso8601String(),
          DatabaseConstants.colCreatedAt: sale.createdAt.toIso8601String(),
          DatabaseConstants.colUpdatedAt: sale.updatedAt.toIso8601String(),
        },
      );

      // 2. Insert Sale Items
      for (final item in sale.items) {
        await txn.insert(
          DatabaseConstants.tableSaleItems,
          {
            DatabaseConstants.colSaleId: saleId,
            DatabaseConstants.colProductId: int.parse(item.productId),
            DatabaseConstants.colProductName: item.productName,
            DatabaseConstants.colQuantity: item.quantity,
            DatabaseConstants.colUnitPrice: item.unitPrice,
            DatabaseConstants.colTotalPrice: item.subTotal,
            DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
          },
        );

        // 3. Update Product Stock (Decrement)
        await txn.rawUpdate(
          'UPDATE ${DatabaseConstants.tableProducts} SET ${DatabaseConstants.colCurrentStock} = ${DatabaseConstants.colCurrentStock} - ? WHERE ${DatabaseConstants.colId} = ?',
          [item.quantity, int.parse(item.productId)],
        );
      }
    });
  }

  Future<List<Sale>> getSales() async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableSales,
      orderBy: '${DatabaseConstants.colSaleDate} DESC',
    );

    return List.generate(maps.length, (i) {
      return Sale(
        id: maps[i][DatabaseConstants.colId].toString(),
        invoiceId: maps[i][DatabaseConstants.colInvoiceNumber],
        customerId: maps[i][DatabaseConstants.colCustomerId]?.toString(),
        totalAmount: maps[i][DatabaseConstants.colTotalAmount],
        discount: maps[i][DatabaseConstants.colDiscount],
        paidAmount: maps[i][DatabaseConstants.colPaidAmount],
        paymentMethod: maps[i][DatabaseConstants.colPaymentType],
        saleDate: DateTime.parse(maps[i][DatabaseConstants.colSaleDate]),
        createdAt: DateTime.parse(maps[i][DatabaseConstants.colCreatedAt]),
        updatedAt: DateTime.parse(maps[i][DatabaseConstants.colUpdatedAt]),
        items: [], // Fetch items lazily if needed
      );
    });
  }
}
