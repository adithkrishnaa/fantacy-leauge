import '../models/transaction.dart';
import 'api_client.dart';

/// `/api/transactions` — wallet history.
class TransactionService {
  TransactionService(this._api);

  final ApiClient _api;

  /// `GET /api/transactions/:userId`
  ///
  /// Any authenticated user may call this; the backend scopes what it returns.
  Future<List<WalletTransaction>> forUser(String userId) async {
    final data = await _api.get('/transactions/$userId');
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => WalletTransaction.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map) {
      final list = data['transactions'] ?? data['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => WalletTransaction.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return const [];
  }

  /// `POST /api/transactions` (admin only)
  Future<void> add({
    required String userId,
    required double amount,
    required String type,
    required String description,
  }) =>
      _api.post('/transactions', body: {
        'user': userId,
        'amount': amount,
        'type': type,
        'description': description,
      });

  /// `DELETE /api/transactions/:id` (admin only)
  Future<void> remove(String id) => _api.delete('/transactions/$id');
}
