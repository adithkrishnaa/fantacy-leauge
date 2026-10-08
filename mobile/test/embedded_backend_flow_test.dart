// End-to-end write-path test for the embedded backend.
//
// DESTRUCTIVE: it inserts and deletes rows, so it only runs against a local
// throwaway database and refuses any other host:
//
//   docker run -d --name fl-test-pg -e POSTGRES_PASSWORD=test -p 55432:5432 postgres:16-alpine
//   (load the schema: `npx prisma migrate diff --from-empty --to-schema prisma/schema.prisma --script`)
//   flutter test test/embedded_backend_flow_test.dart \
//     --dart-define=DATABASE_URL=postgresql://postgres:test@localhost:55432/postgres?sslmode=disable
import 'package:fantasy_league/backend/core.dart';
import 'package:fantasy_league/backend/db.dart';
import 'package:fantasy_league/backend/local_backend.dart';
import 'package:fantasy_league/config/api_config.dart';
import 'package:fantasy_league/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// `bcryptjs.hashSync('webpass123', 10)`, as the Node backend would store it.
const _nodeHash = r'$2b$10$Rme4UwUf9c7pdZkHruVzs.vUDdSosMPiL1n1wS1oCK4OtiuIf0Fuy';

bool get _isLocalDb {
  final host = Uri.tryParse(ApiConfig.databaseUrl)?.host;
  return host == 'localhost' || host == '127.0.0.1';
}

void main() {
  final api = LocalBackend.instance;

  Future<dynamic> call(String method, String path, String? token, [Map<String, dynamic>? body]) =>
      api.handle(method, path, body: body, token: token);

  Matcher apiError(int status) =>
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', status));

  Future<double> credits(String id) async =>
      (await Db.pool.row('SELECT credits FROM "User" WHERE id = @id', {'id': id}))!['credits'] as double;

  setUpAll(() async {
    if (!_isLocalDb) return;
    await Db.pool.execute(
      'TRUNCATE "Winners", "Bet", "Transaction", "Group", "Result", "Match", "Club", "User" CASCADE',
    );
  });

  test('full league lifecycle', () async {
    // --- accounts --------------------------------------------------------
    const adminId = 'admin-1';
    await Db.pool.exec(
      'INSERT INTO "User" (id, "firstName", "lastName", "phoneNumber", password, "userType", "createdAt") '
      'VALUES (@id, \'Ada\', \'Admin\', \'9000000000\', @pw, \'Admin\', now())',
      {'id': adminId, 'pw': _nodeHash},
    );

    // A hash written by bcryptjs (web backend) verifies in the app.
    final adminLogin = await call('POST', '/users/login', null,
        {'phoneNumber': '90000 00000', 'password': 'webpass123'}) as Map;
    final admin = adminLogin['token'] as String;
    expect(adminLogin['userType'], 'Admin');
    await expectLater(
        call('POST', '/users/login', null, {'phoneNumber': '9000000000', 'password': 'nope'}), apiError(401));

    final regA = await call('POST', '/users/register', null, {
      'firstName': 'Alice', 'lastName': 'A', 'phoneNumber': '9111111111', 'password': 'alicepw',
    }) as Map;
    final a = regA['token'] as String;
    final aId = regA['_id'] as String;
    await expectLater(
      call('POST', '/users/register', null,
          {'firstName': 'Dup', 'phoneNumber': '9111111111', 'password': 'x'}),
      apiError(400),
    );

    final stats = await call('GET', '/users/referral-stats', a) as Map;
    final regB = await call('POST', '/users/register', null, {
      'firstName': 'Bob', 'lastName': 'B', 'phoneNumber': '9222222222', 'password': 'bobpw',
      'referralCode': stats['referralCode'],
    }) as Map;
    final b = regB['token'] as String;
    final bId = regB['_id'] as String;
    expect(await credits(aId), 100, reason: 'referral reward');
    expect((await call('GET', '/users/referral-stats', a) as Map)['referralCount'], 1);

    // --- club + manager --------------------------------------------------
    final clubRes = await call('POST', '/clubs', admin, {
      'clubName': 'Lions', 'managerFirstName': 'Max', 'managerLastName': 'M',
      'managerEmail': 'max@example.com', 'countryCode': '+91', 'managerPhone': '9333333333',
      'managerShare': '40', 'adminShare': 60, 'managerPassword': 'maxpw',
    }) as Map;
    final clubId = (clubRes['club'] as Map)['_id'] as String;
    final mLogin = await call('POST', '/users/login', null, {'phoneNumber': '9333333333', 'password': 'maxpw'}) as Map;
    final m = mLogin['token'] as String;
    final mId = mLogin['_id'] as String;
    expect(mLogin['userType'], 'Manager');
    await expectLater(call('POST', '/clubs', m, {}), apiError(403));
    expect((await call('GET', '/clubs', admin) as List).single['user']['_id'], mId);

    // --- membership + credits ---------------------------------------------
    await call('POST', '/users/add-member/$clubId', admin, {'phoneNumber': '9111111111'});
    await call('POST', '/users/add-member', m, {'phoneNumber': '9222222222'});
    await call('POST', '/users/register-member', m, {
      'firstName': 'Cara', 'phoneNumber': '9444444444', 'password': 'carapw',
    });
    expect((await call('GET', '/users/members', m) as List).length, 3);
    expect(((await call('GET', '/users/profile', a) as Map)['memberOf'] as Map)['clubName'], 'Lions');

    await call('PUT', '/users/add-credit/$aId', m, {'creditAmount': 400});
    await call('PUT', '/users/add-credit/$bId', m, {'creditAmount': '500'});
    await call('PUT', '/users/deduct-credit/$bId', m, {'creditAmount': 50});
    await expectLater(call('PUT', '/users/deduct-credit/$bId', m, {'creditAmount': 10000}), apiError(400));
    await expectLater(call('PUT', '/users/add-credit/$aId', m, {'creditAmount': -5}), apiError(400));
    expect(await credits(aId), 500);
    expect(await credits(bId), 450);
    expect((await call('GET', '/transactions/$bId', b) as List).length, 2);
    await expectLater(call('GET', '/transactions/$aId', b), apiError(403));

    // --- match, group, bets ------------------------------------------------
    final matchRes = await call('POST', '/matches', m, {
      'team1': 'India', 'team2': 'Australia',
      'dateTime': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
      'status': 'Active',
    }) as Map;
    final matchId = ((matchRes['data'] as Map)['match'] as Map)['_id'] as String;
    expect((await call('GET', '/matches', m) as List).single['club']['clubName'], 'Lions');
    expect((await call('GET', '/matches/club/$clubId', a) as List).length, 1);

    await call('PUT', '/matches/$matchId/update-players', m, {
      'team1Players': {'1': 'Rohit'}, 'team2Players': {'A': 'Smith'},
    });
    expect(((await call('GET', '/matches/$matchId', a) as Map)['Team1Players'] as Map)['1'], 'Rohit');

    final group = await call('POST', '/groups', m, {
      'matchId': matchId, 'betType': 'First Better', 'betAmount': 50,
      'winnerShare1': 50, 'winnerShare2': 30, 'winnerShare3': 10, 'status': 'Active',
    }) as Map;
    final groupId = group['_id'] as String;
    expect(group['adminShare'], 60);

    final bet = await call('POST', '/bets', a, {
      'betAmount': 50, 'matchId': matchId, 'groupId': groupId, 'combination': '123',
    }) as Map;
    expect((bet['data'] as Map)['newBalance'], 450);
    await expectLater(
      call('POST', '/bets', b, {'betAmount': 50, 'matchId': matchId, 'groupId': groupId, 'combination': '321'}),
      apiError(400),
      reason: 'First Better: combination taken',
    );
    await expectLater(
      call('POST', '/bets', b, {'betAmount': 40, 'matchId': matchId, 'groupId': groupId, 'combination': '456'}),
      apiError(400),
      reason: 'amount must match the group',
    );
    await expectLater(
      call('POST', '/bets', b, {'betAmount': 50, 'matchId': matchId, 'groupId': groupId, 'combination': '889'}),
      apiError(400),
    );
    await call('POST', '/bets/multiple', b, {
      'betAmount': 50, 'matchId': matchId, 'groupId': groupId, 'combinations': ['1AB', '4CD'],
    });
    expect(await credits(bId), 350);
    expect((await call('GET', '/groups/$groupId', a) as Map)['totalBetAmount'], 150);
    expect((await call('GET', '/bets/group/$groupId', m) as List).length, 3);
    expect(((await call('GET', '/bets/my-bets', b) as List).first['match'] as Map)['team1'], 'India');

    // --- result + payout ---------------------------------------------------
    await expectLater(call('POST', '/matches/$matchId/approve-credits', m), apiError(400),
        reason: 'no result yet');
    final result = await call('POST', '/results', m, {
      'matchId': matchId,
      'team1Scores': [10, 20, 30, 40, 0, 0, 0],
      'team2Scores': ['5', 6, 7, 8, 0, 0, 0],
    }) as Map;
    // 123 -> 10+20+30 = 60, 1AB -> 10+5+6 = 21, 4CD -> 40+7+8 = 55
    final scores = {
      for (final x in await call('GET', '/bets/group/$groupId', m) as List) x['combination']: x['score'],
    };
    expect(scores, {'123': 60, '1AB': 21, '4CD': 55});
    expect((await call('GET', '/results/${result['_id']}', m) as Map)['team1Scores'], [10, 20, 30, 40, 0, 0, 0]);

    await call('PUT', '/results/${result['_id']}', m, {
      'team1Scores': [10, 20, 30, 40, 0, 0, 0],
      'team2Scores': [50, 6, 7, 8, 0, 0, 0],
    });
    // 1AB -> 10+50+6 = 66 now leads.

    final adminBefore = await credits(adminId);
    final mBefore = await credits(mId);
    await call('POST', '/matches/$matchId/approve-credits', m);
    // Pot 150: 1st 75 (1AB, Bob), 2nd 45 (123, Alice), 3rd 15 (4CD, Bob);
    // leftover 15 split 60:40 -> admin 9, manager 6.
    expect(await credits(bId), 350 + 75 + 15);
    expect(await credits(aId), 450 + 45);
    expect(await credits(adminId), closeTo(adminBefore + 9, 1e-9));
    expect(await credits(mId), closeTo(mBefore + 6, 1e-9));
    expect((await call('GET', '/matches/$matchId', m) as Map)['status'], 'Announced');
    await expectLater(call('POST', '/matches/$matchId/approve-credits', m), apiError(400));

    final winners = await call('GET', '/winners/group/$groupId', a) as Map;
    expect((winners['firstWinners'] as List).single['combination'], '1AB');
    expect((await call('GET', '/winners/my-winnings', b) as List).length, 1);
    expect((await call('GET', '/bets/my-bets', a) as List).single['result'], 'Win');

    // --- refunds on delete -------------------------------------------------
    final match2 = ((await call('POST', '/matches', m, {
      'team1': 'X', 'team2': 'Y',
      'dateTime': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'status': 'Active',
    }) as Map)['data'] as Map)['match']['_id'] as String;
    final g2 = (await call('POST', '/groups', m, {
      'matchId': match2, 'betType': 'Multi Better', 'betAmount': 20,
      'winnerShare1': 50, 'winnerShare2': 30, 'winnerShare3': 10, 'status': 'Active',
    }) as Map)['_id'] as String;
    await call('POST', '/bets', a, {'betAmount': 20, 'matchId': match2, 'groupId': g2, 'combination': '123'});
    await call('POST', '/bets', b, {'betAmount': 20, 'matchId': match2, 'groupId': g2, 'combination': '123'});
    await expectLater(
      call('POST', '/bets', b, {'betAmount': 20, 'matchId': match2, 'groupId': g2, 'combination': '213'}),
      apiError(400),
      reason: 'Multi Better: same member, same combination',
    );
    final aBefore = await credits(aId);
    final del = await call('DELETE', '/groups/$g2', m) as Map;
    expect(del['refundedBets'], 2);
    expect(await credits(aId), aBefore + 20);
    final delMatch = await call('DELETE', '/matches/$match2', m) as Map;
    expect(delMatch['refundedBets'], 0);
    await expectLater(call('GET', '/matches/$match2', m), apiError(404));
    await call('DELETE', '/matches/$matchId', admin); // settled: nothing refunded
    expect(await credits(aId), aBefore + 20);

    // --- misc ----------------------------------------------------------------
    await call('PUT', '/users/change-password', a, {'currentPassword': 'alicepw', 'newPassword': 'alice2'});
    await expectLater(call('PUT', '/users/change-password', a,
        {'currentPassword': 'wrong', 'newPassword': 'x'}), apiError(400));
    await call('POST', '/users/login', null, {'phoneNumber': '9111111111', 'password': 'alice2'});

    final txn = await call('POST', '/transactions', admin, {'userId': aId, 'amount': 5, 'type': 'Credit'}) as Map;
    await call('DELETE', '/transactions/${((txn['data'] as Map)['transaction'] as Map)['_id']}', admin);

    await expectLater(call('DELETE', '/clubs/$clubId', admin), apiError(409));
    await call('PUT', '/clubs/$clubId', admin, {'clubName': 'Tigers'});
    expect((await call('GET', '/clubs/$clubId', m) as Map)['clubName'], 'Tigers');
    await call('PUT', '/users/remove-member/$aId', m);
    expect((await call('GET', '/users/profile', a) as Map)['memberOf'], isNull);

    // A password hashed by the app verifies the same way the web backend does.
    final appHash = (await Db.pool.row('SELECT password FROM "User" WHERE id = @id', {'id': aId}))!['password'];
    expect(await checkPassword('alice2', appHash as String), isTrue);
    // ignore: avoid_print
    print('APP_HASH=$appHash');
  },
      skip: _isLocalDb ? false : 'Needs a local throwaway DATABASE_URL',
      timeout: const Timeout(Duration(minutes: 3)));
}
