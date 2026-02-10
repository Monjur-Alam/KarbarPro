import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../domain/customer.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper;

  CustomerRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<int> createCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert(
      DatabaseConstants.tableCustomers,
      {
        DatabaseConstants.colName: customer.name,
        DatabaseConstants.colPhone: customer.phone,
        DatabaseConstants.colEmail: customer.email,
        DatabaseConstants.colAddress: customer.address,
        DatabaseConstants.colCurrentCreditBalance: customer.currentCreditBalance,
        DatabaseConstants.colTotalPurchases: customer.totalPurchases,
        DatabaseConstants.colIsActive: customer.isActive ? 1 : 0,
        DatabaseConstants.colCreatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.colIsSynced: 0,
      },
    );
  }

  Future<List<Customer>> getActiveCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colIsActive} = 1',
      orderBy: '${DatabaseConstants.colName} ASC',
    );

    return maps.map((m) => Customer(
      id: m[DatabaseConstants.colId],
      name: m[DatabaseConstants.colName],
      phone: m[DatabaseConstants.colPhone],
      email: m[DatabaseConstants.colEmail],
      address: m[DatabaseConstants.colAddress],
      currentCreditBalance: (m[DatabaseConstants.colCurrentCreditBalance] as num).toDouble(),
      totalPurchases: (m[DatabaseConstants.colTotalPurchases] as num).toDouble(),
      isActive: m[DatabaseConstants.colIsActive] == 1,
      createdAt: DateTime.tryParse(m[DatabaseConstants.colCreatedAt] ?? ''),
      updatedAt: DateTime.tryParse(m[DatabaseConstants.colUpdatedAt] ?? ''),
    )).toList();
  }

  Future<void> updateCustomerCredit(int customerId, double amount) async {
    final db = await _dbHelper.database;
    await db.execute('''
      UPDATE ${DatabaseConstants.tableCustomers} 
      SET ${DatabaseConstants.colCurrentCreditBalance} = ${DatabaseConstants.colCurrentCreditBalance} + ?,
          ${DatabaseConstants.colUpdatedAt} = ?,
          ${DatabaseConstants.colIsSynced} = 0
      WHERE ${DatabaseConstants.colId} = ?
    ''', [amount, DateTime.now().toIso8601String(), customerId]);
  }
}
