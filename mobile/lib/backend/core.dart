import 'dart:isolate';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../services/api_client.dart';
import 'db.dart';

/// One in-app "request": the same shape an Express handler sees.
class Req {
  Req({
    required this.params,
    required this.body,
    this.user,
  });

  final Map<String, String> params;
  final Map<String, dynamic> body;

  /// The signed-in user row (password stripped, `_id` added), or null on
  /// public routes.
  final Map<String, dynamic>? user;

  Map<String, dynamic> get me => user!;
  String get meId => user!['id'] as String;
  String get role => user!['userType'] as String;
}

typedef Handler = Future<dynamic> Function(Req req);

/// Mirrors `res.status(code); throw new Error(message)` in the controllers.
Never fail(String message, [int status = 400]) =>
    throw ApiException(message, statusCode: status);

// --- ids -------------------------------------------------------------------

const _uuid = Uuid();
final _random = Random.secure();

String newId() => _uuid.v4();

String _base36(int length) {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
  return List.generate(length, (_) => chars[_random.nextInt(36)]).join();
}

/// `TXN-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`
String txnCode([String prefix = 'TXN']) =>
    '$prefix-${DateTime.now().millisecondsSinceEpoch}-${_base36(5)}';

DateTime nowUtc() => DateTime.now().toUtc();

// --- passwords (bcrypt, compatible with bcryptjs on the server) -------------

Future<String> hashPassword(String password) => Isolate.run(
      () => BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 10)),
    );

Future<bool> checkPassword(String password, String hash) =>
    Isolate.run(() {
      try {
        return BCrypt.checkpw(password, hash);
      } catch (_) {
        return false;
      }
    });

// --- body parsing (JS-style coercion) --------------------------------------

/// `parseFloat(v)`: numbers pass through, numeric strings parse, else null.
double? toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// JS truthiness for the `!field` checks in the controllers.
bool truthy(dynamic v) {
  if (v == null || v == false) return false;
  if (v is String) return v.isNotEmpty;
  if (v is num) return v != 0 && !v.isNaN;
  return true;
}

String? str(dynamic v) => v?.toString();

String cleanPhone(dynamic v) => (v ?? '').toString().replaceAll(RegExp(r'\s'), '');

// --- response shaping -------------------------------------------------------

/// Converts DB values to what `res.json` would emit: dates become ISO-8601
/// UTC strings, nested maps/lists are converted recursively. Collections come
/// out as `Map<String, dynamic>` / `List<dynamic>`, exactly what decoding the
/// HTTP response would have produced.
dynamic jsonify(dynamic v) {
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) e.key.toString(): jsonify(e.value),
    };
  }
  if (v is List) return <dynamic>[for (final e in v) jsonify(e)];
  return v;
}

/// `{ ...row, _id: row.id }`
Map<String, dynamic> withId(Map<String, dynamic> row) =>
    {...jsonify(row) as Map<String, dynamic>, '_id': row['id']};

/// Same as [withId] but drops the password hash.
Map<String, dynamic> publicUser(Map<String, dynamic> row) =>
    withId(row)..remove('password');

// --- policies (ports of backend/utils/*Policy.js) ---------------------------

void assertMatchOwnership(Map<String, dynamic> user, Map<String, dynamic> match) {
  if (user['userType'] == 'Admin') return;
  if (user['userType'] != 'Manager' || match['manager'] != user['id']) {
    fail('Managers cannot manage a match owned by another manager', 403);
  }
}

void assertMemberOwnership(
  Map<String, dynamic> user,
  Map<String, dynamic>? managerClub,
  Map<String, dynamic> member,
) {
  if (member['userType'] != 'Member') {
    fail('This operation is only allowed for a Member account', 403);
  }
  if (user['userType'] == 'Admin') return;
  if (user['userType'] != 'Manager' ||
      managerClub == null ||
      managerClub['user'] != user['id'] ||
      member['memberOf'] != managerClub['id']) {
    fail('Managers cannot manage a Member from another club', 403);
  }
}

// --- shared queries ---------------------------------------------------------

Future<Map<String, dynamic>?> findUser(Session s, String id) =>
    s.row('SELECT * FROM "User" WHERE id = @id', {'id': id});

Future<Map<String, dynamic>?> findClubOfManager(Session s, String managerId) =>
    s.row('SELECT * FROM "Club" WHERE "user" = @id', {'id': managerId});

Future<Map<String, dynamic>?> findMatch(Session s, String id) =>
    s.row('SELECT * FROM "Match" WHERE id = @id', {'id': id});

/// Inserts a wallet transaction row.
Future<Map<String, dynamic>> insertTransaction(
  Session s, {
  required String user,
  required double amount,
  required String type,
  required String description,
  String? transactionId,
  String? id,
}) async {
  final row = await s.row(
    'INSERT INTO "Transaction" (id, "transactionId", "user", amount, type, description, "createdAt") '
    'VALUES (@id, @tid, @user, @amount:float8, @type, @desc, @now:timestamp) RETURNING *',
    {
      'id': id ?? newId(),
      'tid': transactionId ?? txnCode(),
      'user': user,
      'amount': amount,
      'type': type,
      'desc': description,
      'now': nowUtc(),
    },
  );
  return row!;
}

/// Adds [amount] (may be negative) to a user's wallet.
Future<void> incrementCredits(Session s, String userId, double amount) =>
    s.exec(
      'UPDATE "User" SET credits = credits + @amount:float8 WHERE id = @id',
      {'id': userId, 'amount': amount},
    );

/// JS `amount.toFixed(2)`.
String money(num v) => v.toStringAsFixed(2);
