class DatabaseConstants {
  static const String databaseName = 'amar_dokan.db';
  static const int databaseVersion = 1;

  // Tables
  static const String tableProducts = 'products';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableCustomers = 'customers';
  static const String tableSyncQueue = 'sync_queue';

  // Common Columns
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colIsSynced = 'is_synced';
  static const String colIsDeleted = 'is_deleted';

  // Product Columns
  static const String colName = 'name';
  static const String colDescription = 'description';
  static const String colPrice = 'price';
  static const String colCostPrice = 'cost_price';
  static const String colStockQuantity = 'stock_quantity';
  static const String colUnit = 'unit'; // kg, piece, liter
  static const String colBarcode = 'barcode';
  static const String colImageUrl = 'image_url';

  // Sale Columns
  static const String colInvoiceId = 'invoice_id';
  static const String colCustomerId = 'customer_id';
  static const String colTotalAmount = 'total_amount';
  static const String colDiscount = 'discount';
  static const String colPaidAmount = 'paid_amount';
  static const String colPaymentMethod = 'payment_method';
  static const String colSaleDate = 'sale_date';

  // Sale Item Columns
  static const String colSaleId = 'sale_id';
  static const String colProductId = 'product_id';
  static const String colQuantity = 'quantity';
  static const String colUnitPrice = 'unit_price';
  static const String colSubTotal = 'sub_total';

  // Customer Columns
  static const String colPhone = 'phone';
  static const String colAddress = 'address';
  static const String colTotalPurchases = 'total_purchases';
  
  // Sync Logic
  static const int syncBatchSize = 50;
  static const int maxRetryAttempts = 3;
}
