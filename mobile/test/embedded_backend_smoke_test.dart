// Read-only smoke test for the embedded backend against the real database.
//
//   flutter test test/embedded_backend_smoke_test.dart --dart-define-from-file=backend.env.json
//
// Skipped when no DATABASE_URL is defined. Only GET routes are exercised and
// the match-status sweep is disabled, so nothing is written.
import 'package:fantasy_league/backend/db.dart';
import 'package:fantasy_league/backend/local_backend.dart';
import 'package:fantasy_league/config/api_config.dart';
import 'package:fantasy_league/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final backend = LocalBackend.instance;
  LocalBackend.sweepMatchStatuses = false;

  Future<dynamic> get(String path, String? userId) =>
      backend.handle('GET', path, token: userId == null ? null : 'local.$userId');

  Future<String?> firstId(String sql) async => (await Db.pool.row(sql))?['id'] as String?;

  test('embedded backend serves the read routes', () async {
    final adminId = await firstId('SELECT id FROM "User" WHERE "userType" = \'Admin\' LIMIT 1');
    final managerId = await firstId('SELECT "user" AS id FROM "Club" LIMIT 1');
    final memberId = await firstId(
      'SELECT id FROM "User" WHERE "userType" = \'Member\' AND "memberOf" IS NOT NULL LIMIT 1',
    );
    final matchId = await firstId(
      'SELECT m.id FROM "Match" m WHERE EXISTS (SELECT 1 FROM "Group" g WHERE g.match = m.id) LIMIT 1',
    );
    final groupId = matchId == null
        ? null
        : (await Db.pool.row('SELECT id FROM "Group" WHERE match = @m LIMIT 1', {'m': matchId}))?['id']
            as String?;
    final resultId = await firstId('SELECT result AS id FROM "Match" WHERE result IS NOT NULL LIMIT 1');

    void report(String what, dynamic data) {
      final shape = data is List ? '${data.length} rows' : (data is Map ? 'object' : '$data');
      // ignore: avoid_print
      print('OK  $what -> $shape');
    }

    // Auth failures behave like the middleware.
    await expectLater(get('/users/profile', null),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    await expectLater(
      backend.handle('POST', '/users/login', body: {'phoneNumber': '0000000000', 'password': 'x'}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );

    if (adminId != null) {
      final profile = await get('/users/profile', adminId) as Map<String, dynamic>;
      expect(profile['_id'], adminId);
      expect(profile.containsKey('password'), isFalse);
      report('admin profile', profile);
      final users = await get('/users', adminId) as List;
      expect(users.every((u) => !(u as Map).containsKey('password')), isTrue);
      report('GET /users', users);
      final clubs = await get('/clubs', adminId) as List;
      report('GET /clubs', clubs);
      if (clubs.isNotEmpty) {
        final clubId = (clubs.first as Map)['_id'] as String;
        report('GET /clubs/:id', await get('/clubs/$clubId', adminId));
        report('GET /matches/club/:id', await get('/matches/club/$clubId', adminId));
        report('GET /users/members/:clubId', await get('/users/members/$clubId', adminId));
      }
      report('GET /transactions/:admin', await get('/transactions/$adminId', adminId));
      // Members are refused admin-only routes.
      if (memberId != null) {
        await expectLater(get('/users', memberId),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
      }
    }

    if (managerId != null) {
      report('manager GET /matches', await get('/matches', managerId));
      report('manager GET /users/members', await get('/users/members', managerId));
    }

    if (memberId != null) {
      final profile = await get('/users/profile', memberId) as Map<String, dynamic>;
      expect(profile['memberOf'], isA<Map>());
      report('member profile (with club)', profile);
      report('GET /bets/my-bets', await get('/bets/my-bets', memberId));
      report('GET /winners/my-winnings', await get('/winners/my-winnings', memberId));
      report('GET /transactions/:me', await get('/transactions/$memberId', memberId));
      if (adminId != null) {
        await expectLater(get('/transactions/$adminId', memberId),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
      }
    }

    if (matchId != null && adminId != null) {
      final match = await get('/matches/$matchId', adminId) as Map<String, dynamic>;
      expect(match['dateTime'], isA<String>());
      report('GET /matches/:id', match);
      report('GET /groups/match/:id', await get('/groups/match/$matchId', adminId));
    }
    if (groupId != null && adminId != null) {
      report('GET /groups/:id', await get('/groups/$groupId', adminId));
      report('GET /bets/group/:id', await get('/bets/group/$groupId', adminId));
      report('GET /winners/group/:id', await get('/winners/group/$groupId', adminId));
    }
    if (resultId != null && adminId != null) {
      final result = await get('/results/$resultId', adminId) as Map<String, dynamic>;
      expect(result['team1Scores'], isA<List>());
      report('GET /results/:id', result);
    }
  }, skip: ApiConfig.embedded ? false : 'No DATABASE_URL defined', timeout: const Timeout(Duration(minutes: 2)));
}
