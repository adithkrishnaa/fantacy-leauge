import 'package:postgres/postgres.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';

/// Direct connection to the shared Postgres database (the same one the
/// Express backend and React web app use).
///
/// The connection string comes from `--dart-define=DATABASE_URL=...` at build
/// time, so it never lives in source control. Anyone holding the APK can
/// extract it, which is why this build is for personal testing only.
class Db {
  Db._();

  static Pool<void>? _pool;

  static Pool<void> get pool {
    final url = ApiConfig.databaseUrl;
    if (url.isEmpty) {
      throw ApiException(
        'This build has no database configured. Rebuild with '
        '--dart-define-from-file=backend.env.json.',
        statusCode: 500,
      );
    }
    return _pool ??= Pool.withUrl(_withPoolSettings(url));
  }

  /// A phone only needs a couple of connections; keep them short-lived so a
  /// backgrounded app doesn't hold a dead socket.
  static String _withPoolSettings(String url) {
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters)
      ..putIfAbsent('max_connection_count', () => '2')
      ..putIfAbsent('max_connection_age', () => '300')
      ..putIfAbsent('connect_timeout', () => '20')
      ..putIfAbsent('query_timeout', () => '60');
    return uri.replace(queryParameters: params).toString();
  }

  static Future<R> tx<R>(Future<R> Function(TxSession s) fn) =>
      pool.runTx(fn);
}

/// Small query helpers. `sql` uses named `@params`; annotate non-text values
/// with their Postgres type (`@amount:float8`, `@ids:_text`, ...).
extension SessionQueries on Session {
  Future<List<Map<String, dynamic>>> rows(
    String sql, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await execute(Sql.named(sql), parameters: params);
    return result.map((r) => r.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>?> row(
    String sql, [
    Map<String, Object?> params = const {},
  ]) async {
    final list = await rows(sql, params);
    return list.isEmpty ? null : list.first;
  }

  /// Runs a statement and returns the number of affected rows.
  Future<int> exec(
    String sql, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await execute(Sql.named(sql), parameters: params);
    return result.affectedRows;
  }
}
