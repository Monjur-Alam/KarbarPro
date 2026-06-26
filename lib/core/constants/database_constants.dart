class DatabaseConstants {
  static const String databaseName = 'amar_dokan.db';
  static const int databaseVersion = 14;

  // New Customer Columns
  static const String colCustomerType = 'type'; // 'customer' or 'supplier'
  static const String colTotalCredit = 'total_credit';
  static const String colTotalPaid = 'total_paid';


  // Table Names
  static const String tableProducts = 'products';
  static const String tableCustomers = 'customers';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableExpenses = 'expenses';
  static const String tableCreditPayments = 'credit_payments';
  static const String tableSyncLog = 'sync_log';
  static const String tableAppSettings = 'app_settings';
  static const String tableCustomerTransactions = 'customer_transactions';
  static const String tableShopTransactions = 'shop_transactions';
  static const String tableKhorochCategories = 'khoroch_categories';
  static const String tableProductCategories = 'product_categories';
  static const String tableProductBrands = 'product_brands';
  static const String tableProductUnits = 'product_units';
  static const String tableProductColors = 'product_colors';

  // Common Columns
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colSyncedAt = 'synced_at';
  static const String colIsSynced = 'is_synced';
  static const String colIsActive = 'is_active';
  static const String colDeletedAt = 'deleted_at';
  static const String colTransactionType = 'transaction_type'; // sale, payment, income, expense
  static const String colBalanceAfter = 'balance_after_transaction';
  static const String colTransactionDate = 'transaction_date';
  static const String colTransactionSource = 'transaction_source'; // manual_khoroch, product_sale, credit_payment, system
  static const String colCategoryId = 'category_id';
  static const String colIsManual = 'is_manual';

  // Products Columns
  static const String colName = 'name';
  static const String colNameBengali = 'name_bengali';
  static const String colCategory = 'category';
  static const String colPurchasePrice = 'purchase_price';
  static const String colSellingPrice = 'selling_price';
  static const String colCurrentStock = 'current_stock';
  static const String colMinStockAlert = 'min_stock_alert';
  static const String colUnit = 'unit';
  static const String colBarcode = 'barcode';
  static const String colSize = 'size';
  static const String colImagePath = 'image_path';

  // Customers Columns
  static const String colPhone = 'phone';
  static const String colEmail = 'email';
  static const String colAddress = 'address';
  static const String colCreditLimit = 'credit_limit';
  static const String colCurrentCreditBalance = 'current_credit_balance';
  static const String colTotalPurchases = 'total_purchases';

  // Sales Columns
  static const String colInvoiceNumber = 'invoice_number';
  static const String colCustomerId = 'customer_id';
  static const String colPaymentType = 'payment_type';
  static const String colSubtotal = 'subtotal';
  static const String colDiscount = 'discount';
  static const String colTotalAmount = 'total_amount';
  static const String colTotalProfit = 'total_profit';
  static const String colPaymentStatus = 'payment_status';
  static const String colPaidAmount = 'paid_amount';
  static const String colDueAmount = 'due_amount';
  static const String colSaleDate = 'sale_date';
  static const String colNotes = 'notes';

  // Sale Items Columns
  static const String colSaleId = 'sale_id';
  static const String colProductId = 'product_id';
  static const String colProductName = 'product_name';
  static const String colQuantity = 'quantity';
  static const String colUnitPrice = 'unit_price';
  static const String colTotalPrice = 'total_price';
  static const String colProfit = 'profit';

  // Expenses Columns
  static const String colAmount = 'amount';
  static const String colDescription = 'description';
  static const String colExpenseDate = 'expense_date';
  static const String colPaymentMethod = 'payment_method';

  // Credit Payments Columns
  static const String colPaymentDate = 'payment_date';

  // Activities Columns
  static const String colVisitId = 'visit_id';
  static const String colActivityType = 'activity_type';
  static const String colOutcome = 'outcome';
  static const String colOutcomeNotes = 'outcome_notes';
  static const String colFollowUpRequired = 'follow_up_required';
  static const String colFollowUpDate = 'follow_up_date';
  static const String colFollowUpNotes = 'follow_up_notes';
  static const String colActivityDate = 'activity_date';

  // Sync Log Columns
  static const String colSyncType = 'sync_type';
  static const String colSyncStatus = 'sync_status';
  static const String colTablesSynced = 'tables_synced';
  static const String colRecordsSynced = 'records_synced';
  static const String colErrorMessage = 'error_message';
  static const String colStartedAt = 'started_at';
  static const String colCompletedAt = 'completed_at';

  // App Settings Columns
  static const String colKey = 'key';
  static const String colValue = 'value';
}
