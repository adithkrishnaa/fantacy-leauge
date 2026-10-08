import '../core.dart';
import '../db.dart';

/// Port of `backend/controllers/TransactionController.js`.

// POST /api/transactions
Future<dynamic> addTransaction(Req req) async {
  final b = req.body;
  final amount = toDouble(b['amount']);
  if (!truthy(b['userId']) || !truthy(b['amount']) || !truthy(b['type']) || amount == null) {
    fail('All required fields must be provided.');
  }
  final type = b['type'].toString();
  final txn = await insertTransaction(
    Db.pool,
    user: b['userId'].toString(),
    amount: amount,
    type: type,
    description: truthy(b['description']) ? b['description'].toString() : 'Transaction ($type)',
  );
  return {
    'success': true,
    'message': 'Transaction added successfully!',
    'data': {'transaction': withId(txn), 'notificationQueued': true},
  };
}

// GET /api/transactions/:userId
Future<dynamic> getTransactionsByUser(Req req) async {
  final userId = req.params['userId']!;
  if (req.role != 'Admin' && req.meId != userId) {
    fail('Users can only view their own transaction history', 403);
  }
  final rows = await Db.pool.rows(
    'SELECT * FROM "Transaction" WHERE "user" = @u ORDER BY "createdAt" DESC',
    {'u': userId},
  );
  return rows.map(withId).toList();
}

// DELETE /api/transactions/:id
Future<dynamic> deleteTransaction(Req req) async {
  final deleted = await Db.pool.exec(
    'DELETE FROM "Transaction" WHERE id = @id',
    {'id': req.params['id']},
  );
  if (deleted == 0) fail('Transaction not found.', 404);
  return {'message': 'Transaction deleted successfully.'};
}
