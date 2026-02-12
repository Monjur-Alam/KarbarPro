import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/database_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    print('DB_LOG: Initializing Database...');
    _database = await _initDatabase();
    print('DB_LOG: Database Initialized.');
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), DatabaseConstants.databaseName);
    return await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTransactionTables(db);
    }
    if (oldVersion < 3) {
      await _addTransactionSourceColumn(db);
    }
    print('DB_LOG: Upgrading DB from $oldVersion to $newVersion');
    if (oldVersion < 4) {
      await _upgradeToVersion4(db);
    }
    if (oldVersion < 5) {
      print('DB_LOG: Upgrading to Version 5...');
      await _upgradeToVersion5(db);
      print('DB_LOG: Upgrade to Version 5 Complete.');
    }
    if (oldVersion < 6) {
      print('DB_LOG: Upgrading to Version 6...');
      await _upgradeToVersion6(db);
      print('DB_LOG: Upgrade to Version 6 Complete.');
    }
  }

  Future _onCreate(Database db, int version) async {
    // 1. Products Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableProducts} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colName} TEXT NOT NULL,
        ${DatabaseConstants.colNameBengali} TEXT,
        ${DatabaseConstants.colCategory} TEXT,
        ${DatabaseConstants.colPurchasePrice} REAL NOT NULL CHECK (${DatabaseConstants.colPurchasePrice} > 0),
        ${DatabaseConstants.colSellingPrice} REAL NOT NULL CHECK (${DatabaseConstants.colSellingPrice} > 0),
        ${DatabaseConstants.colCurrentStock} INTEGER DEFAULT 0 CHECK (${DatabaseConstants.colCurrentStock} >= 0),
        ${DatabaseConstants.colMinStockAlert} INTEGER DEFAULT 5,
        ${DatabaseConstants.colUnit} TEXT,
        ${DatabaseConstants.colBarcode} TEXT UNIQUE,
        ${DatabaseConstants.colImagePath} TEXT,
        ${DatabaseConstants.colIsActive} INTEGER DEFAULT 1,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colName})');
    await db.execute('CREATE INDEX idx_products_category ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colCategory})');
    await db.execute('CREATE INDEX idx_products_active ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colIsActive})');

    // 2. Customers Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCustomers} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colName} TEXT NOT NULL,
        ${DatabaseConstants.colPhone} TEXT UNIQUE,
        ${DatabaseConstants.colEmail} TEXT,
        ${DatabaseConstants.colAddress} TEXT,
        ${DatabaseConstants.colCreditLimit} REAL DEFAULT 0,
        ${DatabaseConstants.colCurrentCreditBalance} REAL DEFAULT 0,
        ${DatabaseConstants.colTotalPurchases} REAL DEFAULT 0,
        ${DatabaseConstants.colIsActive} INTEGER DEFAULT 1,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_customers_phone ON ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colPhone})');
    await db.execute('CREATE INDEX idx_customers_name ON ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colName})');

    // 3. Sales Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSales} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colInvoiceNumber} TEXT UNIQUE NOT NULL,
        ${DatabaseConstants.colCustomerId} INTEGER,
        ${DatabaseConstants.colPaymentType} TEXT NOT NULL,
        ${DatabaseConstants.colSubtotal} REAL NOT NULL,
        ${DatabaseConstants.colDiscount} REAL DEFAULT 0,
        ${DatabaseConstants.colTotalAmount} REAL NOT NULL,
        ${DatabaseConstants.colTotalProfit} REAL,
        ${DatabaseConstants.colPaymentStatus} TEXT,
        ${DatabaseConstants.colPaidAmount} REAL DEFAULT 0,
        ${DatabaseConstants.colDueAmount} REAL DEFAULT 0,
        ${DatabaseConstants.colSaleDate} TEXT NOT NULL,
        ${DatabaseConstants.colNotes} TEXT,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0,
        FOREIGN KEY (${DatabaseConstants.colCustomerId}) REFERENCES ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colId}) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_date ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colSaleDate})');
    await db.execute('CREATE INDEX idx_sales_customer ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colCustomerId})');
    await db.execute('CREATE INDEX idx_sales_invoice ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colInvoiceNumber})');
    await db.execute('CREATE INDEX idx_sales_payment_type ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colPaymentType})');

    // 4. Sale Items Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSaleItems} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colSaleId} INTEGER NOT NULL,
        ${DatabaseConstants.colProductId} INTEGER NOT NULL,
        ${DatabaseConstants.colProductName} TEXT NOT NULL,
        ${DatabaseConstants.colQuantity} REAL NOT NULL,
        ${DatabaseConstants.colUnitPrice} REAL NOT NULL,
        ${DatabaseConstants.colPurchasePrice} REAL,
        ${DatabaseConstants.colDiscount} REAL DEFAULT 0,
        ${DatabaseConstants.colTotalPrice} REAL NOT NULL,
        ${DatabaseConstants.colProfit} REAL,
        ${DatabaseConstants.colCreatedAt} TEXT,
        FOREIGN KEY (${DatabaseConstants.colSaleId}) REFERENCES ${DatabaseConstants.tableSales} (${DatabaseConstants.colId}) ON DELETE CASCADE,
        FOREIGN KEY (${DatabaseConstants.colProductId}) REFERENCES ${DatabaseConstants.tableProducts} (${DatabaseConstants.colId}) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_sale_items_sale ON ${DatabaseConstants.tableSaleItems} (${DatabaseConstants.colSaleId})');
    await db.execute('CREATE INDEX idx_sale_items_product ON ${DatabaseConstants.tableSaleItems} (${DatabaseConstants.colProductId})');

    // 5. Expenses Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableExpenses} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colCategory} TEXT NOT NULL,
        ${DatabaseConstants.colAmount} REAL NOT NULL,
        ${DatabaseConstants.colDescription} TEXT,
        ${DatabaseConstants.colExpenseDate} TEXT NOT NULL,
        ${DatabaseConstants.colPaymentMethod} TEXT,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON ${DatabaseConstants.tableExpenses} (${DatabaseConstants.colExpenseDate})');
    await db.execute('CREATE INDEX idx_expenses_cat ON ${DatabaseConstants.tableExpenses} (${DatabaseConstants.colCategory})');

    // 6. Credit Payments Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCreditPayments} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colSaleId} INTEGER,
        ${DatabaseConstants.colCustomerId} INTEGER NOT NULL,
        ${DatabaseConstants.colAmount} REAL NOT NULL,
        ${DatabaseConstants.colPaymentMethod} TEXT,
        ${DatabaseConstants.colPaymentDate} TEXT NOT NULL,
        ${DatabaseConstants.colNotes} TEXT,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0,
        FOREIGN KEY (${DatabaseConstants.colSaleId}) REFERENCES ${DatabaseConstants.tableSales} (${DatabaseConstants.colId}) ON DELETE SET NULL,
        FOREIGN KEY (${DatabaseConstants.colCustomerId}) REFERENCES ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colId}) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_credit_payments_cust ON ${DatabaseConstants.tableCreditPayments} (${DatabaseConstants.colCustomerId})');
    await db.execute('CREATE INDEX idx_credit_payments_date ON ${DatabaseConstants.tableCreditPayments} (${DatabaseConstants.colPaymentDate})');

    // 7. Activities Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableActivities} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colVisitId} TEXT,
        ${DatabaseConstants.colCustomerId} INTEGER,
        ${DatabaseConstants.colActivityType} TEXT,
        ${DatabaseConstants.colOutcome} TEXT,
        ${DatabaseConstants.colOutcomeNotes} TEXT,
        ${DatabaseConstants.colFollowUpRequired} INTEGER DEFAULT 0,
        ${DatabaseConstants.colFollowUpDate} TEXT,
        ${DatabaseConstants.colFollowUpNotes} TEXT,
        ${DatabaseConstants.colActivityDate} TEXT NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0,
        FOREIGN KEY (${DatabaseConstants.colCustomerId}) REFERENCES ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colId}) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_activities_cust ON ${DatabaseConstants.tableActivities} (${DatabaseConstants.colCustomerId})');
    await db.execute('CREATE INDEX idx_activities_date ON ${DatabaseConstants.tableActivities} (${DatabaseConstants.colActivityDate})');

    // 8. Sync Log Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSyncLog} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colSyncType} TEXT,
        ${DatabaseConstants.colSyncStatus} TEXT,
        ${DatabaseConstants.colTablesSynced} TEXT,
        ${DatabaseConstants.colRecordsSynced} INTEGER,
        ${DatabaseConstants.colErrorMessage} TEXT,
        ${DatabaseConstants.colStartedAt} TEXT,
        ${DatabaseConstants.colCompletedAt} TEXT
      )
    ''');

    // 9. App Settings Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableAppSettings} (
        ${DatabaseConstants.colKey} TEXT PRIMARY KEY,
        ${DatabaseConstants.colValue} TEXT,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT
      )
    ''');

    // Insert Default Settings
    await db.insert(DatabaseConstants.tableAppSettings, {
      DatabaseConstants.colKey: 'currency',
      DatabaseConstants.colValue: '৳',
      DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String()
    });
    await db.insert(DatabaseConstants.tableAppSettings, {
      DatabaseConstants.colKey: 'language',
      DatabaseConstants.colValue: 'Bengali',
      DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String()
    });

    await _createTransactionTables(db);
    await _createKhorochCategoryTable(db);
  }

  Future<void> _createTransactionTables(Database db) async {
    // 10. Customer Transactions Table (Ledger History)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCustomerTransactions} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colCustomerId} INTEGER NOT NULL,
        ${DatabaseConstants.colTransactionType} TEXT NOT NULL,
        ${DatabaseConstants.colAmount} REAL NOT NULL,
        ${DatabaseConstants.colBalanceAfter} REAL NOT NULL,
        ${DatabaseConstants.colDescription} TEXT,
        ${DatabaseConstants.colTransactionDate} TEXT NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0,
        FOREIGN KEY (${DatabaseConstants.colCustomerId}) REFERENCES ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colId}) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_customer_trans_cust ON ${DatabaseConstants.tableCustomerTransactions} (${DatabaseConstants.colCustomerId})');
    await db.execute('CREATE INDEX idx_customer_trans_date ON ${DatabaseConstants.tableCustomerTransactions} (${DatabaseConstants.colTransactionDate})');

    // 11. Shop Transactions Table (Main Balance History)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableShopTransactions} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colTransactionType} TEXT NOT NULL,
        ${DatabaseConstants.colAmount} REAL NOT NULL,
        ${DatabaseConstants.colBalanceAfter} REAL NOT NULL,
        ${DatabaseConstants.colCategory} TEXT,
        ${DatabaseConstants.colDescription} TEXT,
        ${DatabaseConstants.colTransactionDate} TEXT NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT,
        ${DatabaseConstants.colSyncedAt} TEXT,
        ${DatabaseConstants.colTransactionSource} TEXT DEFAULT 'manual_khoroch',
        ${DatabaseConstants.colCategoryId} INTEGER,
        ${DatabaseConstants.colIsManual} INTEGER DEFAULT 1,
        ${DatabaseConstants.colDeletedAt} TEXT,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_shop_trans_date ON ${DatabaseConstants.tableShopTransactions} (${DatabaseConstants.colTransactionDate})');
    await db.execute('CREATE INDEX idx_shop_trans_type ON ${DatabaseConstants.tableShopTransactions} (${DatabaseConstants.colTransactionType})');
  }

  Future<void> _addTransactionSourceColumn(Database db) async {
    // Add transaction_source column to shop_transactions table
    await db.execute('''
      ALTER TABLE ${DatabaseConstants.tableShopTransactions} 
      ADD COLUMN ${DatabaseConstants.colTransactionSource} TEXT DEFAULT 'manual_khoroch'
    ''');

    // Migrate existing data based on category
    // Product sales
    await db.execute('''
      UPDATE ${DatabaseConstants.tableShopTransactions}
      SET ${DatabaseConstants.colTransactionSource} = 'product_sale'
      WHERE ${DatabaseConstants.colCategory} IN ('বিক্রয় থেকে আয়', 'Shop Sale', 'Sale', 'পণ্য বিক্রয়')
    ''');

    // Credit payments / collections
    await db.execute('''
      UPDATE ${DatabaseConstants.tableShopTransactions}
      SET ${DatabaseConstants.colTransactionSource} = 'credit_payment'
      WHERE ${DatabaseConstants.colCategory} IN ('বকেয়া সংগ্রহ', 'Credit Payment', 'Collection', 'হালখাতা', 'বকেয়া পরিশোধ')
    ''');
  }

  Future<void> _upgradeToVersion4(Database db) async {
    await _createKhorochCategoryTable(db);

    // Add category_id to shop_transactions (only for upgrades, onCreate already has it)
    await db.execute('''
      ALTER TABLE ${DatabaseConstants.tableShopTransactions}
      ADD COLUMN ${DatabaseConstants.colCategoryId} INTEGER
    ''');
  }

  Future<void> _upgradeToVersion5(Database db) async {
    // Add is_manual column
    await db.execute('''
      ALTER TABLE ${DatabaseConstants.tableShopTransactions}
      ADD COLUMN ${DatabaseConstants.colIsManual} INTEGER DEFAULT 0
    ''');

    // Add deleted_at column
    await db.execute('''
      ALTER TABLE ${DatabaseConstants.tableShopTransactions}
      ADD COLUMN ${DatabaseConstants.colDeletedAt} TEXT
    ''');

    // Initialize is_manual: 1 for manual_khoroch, 0 for others
    final count = await db.execute('''
      UPDATE ${DatabaseConstants.tableShopTransactions}
      SET ${DatabaseConstants.colIsManual} = 1
      WHERE ${DatabaseConstants.colTransactionSource} = 'manual_khoroch'
    ''');
    print('DB_LOG: Version 5 Migration - is_manual initialized.');
  }

  Future<void> _upgradeToVersion6(Database db) async {
    // Add missing updated_at column to shop_transactions
    await db.execute('''
      ALTER TABLE ${DatabaseConstants.tableShopTransactions}
      ADD COLUMN ${DatabaseConstants.colUpdatedAt} TEXT
    ''');
    print('DB_LOG: Version 6 Migration - updated_at added to shop_transactions.');
  }

  Future<void> _createKhorochCategoryTable(Database db) async {
    // 1. Create Categories Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableKhorochCategories} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colName} TEXT NOT NULL UNIQUE,
        ${DatabaseConstants.colTransactionType} TEXT NOT NULL, -- 'income' or 'expense'
        ${DatabaseConstants.colIsActive} INTEGER DEFAULT 1,
        ${DatabaseConstants.colCreatedAt} TEXT,
        ${DatabaseConstants.colUpdatedAt} TEXT
      )
    ''');

    // 2. Pre-populate with default categories
    final now = DateTime.now().toIso8601String();
    final categories = [
      {'name': 'দোকান বিক্রয়', 'type': 'income'},
      {'name': 'ব্যক্তিগত', 'type': 'income'},
      {'name': 'ঋণ', 'type': 'income'},
      {'name': 'বিবিধ', 'type': 'income'},
      {'name': 'ভাড়া', 'type': 'expense'},
      {'name': 'বেতন', 'type': 'expense'},
      {'name': 'পণ্য ক্রয়', 'type': 'expense'},
      {'name': 'বিদ্যুৎ বিল', 'type': 'expense'},
      {'name': 'অন্যান্য', 'type': 'expense'},
    ];

    for (var cat in categories) {
      await db.insert(DatabaseConstants.tableKhorochCategories, {
        DatabaseConstants.colName: cat['name'],
        DatabaseConstants.colTransactionType: cat['type'],
        DatabaseConstants.colIsActive: 1,
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      });
    }
  }

  // Generic CRUD Operations
  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await database;
    row[DatabaseConstants.colCreatedAt] = DateTime.now().toIso8601String();
    row[DatabaseConstants.colUpdatedAt] = DateTime.now().toIso8601String();
    row[DatabaseConstants.colIsSynced] = 0;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  Future<int> update(String table, Map<String, dynamic> row) async {
    Database db = await database;
    int id = row[DatabaseConstants.colId];
    row[DatabaseConstants.colUpdatedAt] = DateTime.now().toIso8601String();
    row[DatabaseConstants.colIsSynced] = 0;
    return await db.update(table, row, where: '${DatabaseConstants.colId} = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, int id) async {
    Database db = await database;
    return await db.delete(table, where: '${DatabaseConstants.colId} = ?', whereArgs: [id]);
  }

  // Batch Operations
  Future<void> batchInsert(String table, List<Map<String, dynamic>> rows) async {
    Database db = await database;
    await db.transaction((txn) async {
      Batch batch = txn.batch();
      for (var row in rows) {
        row[DatabaseConstants.colCreatedAt] = DateTime.now().toIso8601String();
        row[DatabaseConstants.colUpdatedAt] = DateTime.now().toIso8601String();
        row[DatabaseConstants.colIsSynced] = 0;
        batch.insert(table, row);
      }
      await batch.commit(noResult: true);
    });
  }

  // Business Queries
  Future<List<Map<String, dynamic>>> getDailySales(String date) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT * FROM ${DatabaseConstants.tableSales} 
      WHERE date(${DatabaseConstants.colSaleDate}) = date(?)
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getMonthlyReport(String yearMonth) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT strftime('%Y-%m', ${DatabaseConstants.colSaleDate}) as month,
             SUM(${DatabaseConstants.colTotalAmount}) as total_revenue,
             SUM(${DatabaseConstants.colTotalProfit}) as total_profit
      FROM ${DatabaseConstants.tableSales}
      WHERE month = ?
      GROUP BY month
    ''', [yearMonth]);
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts(int limit) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT ${DatabaseConstants.colProductName}, SUM(${DatabaseConstants.colQuantity}) as total_qty
      FROM ${DatabaseConstants.tableSaleItems}
      GROUP BY ${DatabaseConstants.colProductId}
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [limit]);
  }

  // Sync Helpers
  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    Database db = await database;
    return await db.query(table, where: '${DatabaseConstants.colIsSynced} = 0');
  }

  Future<void> markAsSynced(String table, List<int> ids) async {
    Database db = await database;
    String idList = ids.join(',');
    await db.rawUpdate('''
      UPDATE $table 
      SET ${DatabaseConstants.colIsSynced} = 1, ${DatabaseConstants.colSyncedAt} = ?
      WHERE ${DatabaseConstants.colId} IN ($idList)
    ''', [DateTime.now().toIso8601String()]);
  }

  // Maintenance
  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), DatabaseConstants.databaseName);
  }

  Future<void> backupDatabase(String backupPath) async {
    String dbPath = await getDatabasePath();
    File dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.copy(backupPath);
    }
  }

  Future<void> restoreDatabase(String backupPath) async {
    String dbPath = await getDatabasePath();
    File backupFile = File(backupPath);
    if (await backupFile.exists()) {
      await _database?.close();
      await backupFile.copy(dbPath);
      _database = await _initDatabase();
    }
  }

  Future<void> clearAllTables() async {
    Database db = await database;
    await db.transaction((txn) async {
      var tables = await txn.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
      for (var table in tables) {
        String tableName = table['name'] as String;
        if (tableName != 'android_metadata' && tableName != 'sqlite_sequence') {
          await txn.delete(tableName);
        }
      }
    });
  }

  Future<void> vacuum() async {
    Database db = await database;
    await db.execute('VACUUM');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
