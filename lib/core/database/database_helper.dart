import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/database_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DatabaseConstants.databaseName);

    return await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // 1. Products Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableProducts} (
        ${DatabaseConstants.colId} TEXT PRIMARY KEY,
        ${DatabaseConstants.colName} TEXT NOT NULL,
        ${DatabaseConstants.colDescription} TEXT,
        ${DatabaseConstants.colPrice} REAL NOT NULL,
        ${DatabaseConstants.colCostPrice} REAL,
        ${DatabaseConstants.colStockQuantity} INTEGER DEFAULT 0,
        ${DatabaseConstants.colUnit} TEXT DEFAULT 'pcs',
        ${DatabaseConstants.colBarcode} TEXT,
        ${DatabaseConstants.colImageUrl} TEXT,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0,
        ${DatabaseConstants.colIsDeleted} INTEGER DEFAULT 0
      )
    ''');

    // 2. Customers Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCustomers} (
        ${DatabaseConstants.colId} TEXT PRIMARY KEY,
        ${DatabaseConstants.colName} TEXT NOT NULL,
        ${DatabaseConstants.colPhone} TEXT,
        ${DatabaseConstants.colAddress} TEXT,
        ${DatabaseConstants.colTotalPurchases} REAL DEFAULT 0.0,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0,
        ${DatabaseConstants.colIsDeleted} INTEGER DEFAULT 0
      )
    ''');

    // 3. Sales Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSales} (
        ${DatabaseConstants.colId} TEXT PRIMARY KEY,
        ${DatabaseConstants.colInvoiceId} TEXT NOT NULL UNIQUE,
        ${DatabaseConstants.colCustomerId} TEXT,
        ${DatabaseConstants.colTotalAmount} REAL NOT NULL,
        ${DatabaseConstants.colDiscount} REAL DEFAULT 0.0,
        ${DatabaseConstants.colPaidAmount} REAL NOT NULL,
        ${DatabaseConstants.colPaymentMethod} TEXT DEFAULT 'cash',
        ${DatabaseConstants.colSaleDate} TEXT NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colIsSynced} INTEGER DEFAULT 0,
        ${DatabaseConstants.colIsDeleted} INTEGER DEFAULT 0,
        FOREIGN KEY (${DatabaseConstants.colCustomerId}) 
          REFERENCES ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colId})
      )
    ''');

    // 4. Sale Items Table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSaleItems} (
        ${DatabaseConstants.colId} TEXT PRIMARY KEY,
        ${DatabaseConstants.colSaleId} TEXT NOT NULL,
        ${DatabaseConstants.colProductId} TEXT NOT NULL,
        ${DatabaseConstants.colQuantity} INTEGER NOT NULL,
        ${DatabaseConstants.colUnitPrice} REAL NOT NULL,
        ${DatabaseConstants.colSubTotal} REAL NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        FOREIGN KEY (${DatabaseConstants.colSaleId}) 
          REFERENCES ${DatabaseConstants.tableSales} (${DatabaseConstants.colId}) 
          ON DELETE CASCADE,
        FOREIGN KEY (${DatabaseConstants.colProductId}) 
          REFERENCES ${DatabaseConstants.tableProducts} (${DatabaseConstants.colId})
      )
    ''');

    // 5. Sync Queue Table (for offline-first sync)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSyncQueue} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        action TEXT NOT NULL, -- CREATE, UPDATE, DELETE
        record_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here in future versions
  }

  // Generic Helper Methods

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table, where: '${DatabaseConstants.colIsDeleted} = ?', whereArgs: [0]);
  }

  Future<Map<String, dynamic>?> queryById(String table, String id) async {
    final db = await database;
    final results = await db.query(
      table,
      where: '${DatabaseConstants.colId} = ? AND ${DatabaseConstants.colIsDeleted} = ?',
      whereArgs: [id, 0],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String table, String id) async {
    // Soft delete
    final db = await database;
    return await db.update(
      table,
      {DatabaseConstants.colIsDeleted: 1, DatabaseConstants.colIsSynced: 0},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }
}
