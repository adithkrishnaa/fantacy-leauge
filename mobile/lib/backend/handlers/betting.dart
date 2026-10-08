import '../core.dart';
import '../db.dart';
import 'matches.dart' show refundOpenBets;

/// Ports of `groupController.js`, `betController.js`, `winnerController.js`
/// and the inline handler in `routes/winnerRoutes.js`.

// --- groups ----------------------------------------------------------------

Future<List<Map<String, dynamic>>> _groupsWithMatch(List<Map<String, dynamic>> groups) async {
  final ids = groups.map((g) => g['match'] as String).toSet().toList();
  final matches = ids.isEmpty
      ? <Map<String, dynamic>>[]
      : await Db.pool.rows(
          'SELECT id, team1, team2, "dateTime" FROM "Match" WHERE id = ANY(@ids:_text)',
          {'ids': ids},
        );
  final byId = {for (final m in matches) m['id']: m};
  return groups.map((g) {
    final m = byId[g['match']];
    return {
      ...withId(g),
      'match': m == null
          ? null
          : {
              '_id': m['id'],
              'team1': m['team1'],
              'team2': m['team2'],
              'dateTime': jsonify(m['dateTime']),
            },
    };
  }).toList();
}

void _checkBiddingIncrement(Map<String, dynamic> b) {
  if (b['betType'] == 'Bidding Method' && toDouble(b['minimumIncrement']) == null) {
    fail('Minimum increment is required for Bidding Method');
  }
}

double _requiredDouble(dynamic v, String field) {
  final d = toDouble(v);
  if (d == null || d.isNaN) fail('$field must be a number');
  return d;
}

// POST /api/groups
Future<dynamic> createGroup(Req req) async {
  final b = req.body;
  final pool = Db.pool;
  final match = await findMatch(pool, str(b['matchId']) ?? '');
  if (match == null) fail('Match not found', 404);
  assertMatchOwnership(req.me, match);
  _checkBiddingIncrement(b);

  final club = await pool.row('SELECT * FROM "Club" WHERE id = @id', {'id': match['club']});
  if (club == null) fail('Club not found for this match', 404);

  final betType = truthy(b['betType']) ? b['betType'].toString() : 'First Better';
  final group = await pool.row(
    'INSERT INTO "Group" (id, "betType", "betAmount", "minimumIncrement", match, status, "totalBetAmount", '
    '"winnerShare1", "winnerShare2", "winnerShare3", "adminShare", "managerShare", '
    '"CombinationsMaster", "SelectedCombinations", "createdAt") '
    'VALUES (@id, @type, @amount:float8, @inc:float8, @match, @status, 0, @w1:float8, @w2:float8, @w3:float8, '
    '@as:float8, @ms:float8, \'{}\'::text[], \'{}\'::text[], @now:timestamp) RETURNING *',
    {
      'id': newId(),
      'type': betType,
      'amount': _requiredDouble(b['betAmount'], 'Bet amount'),
      'inc': betType == 'Bidding Method' ? toDouble(b['minimumIncrement']) : null,
      'match': match['id'],
      'status': truthy(b['status']) ? b['status'].toString() : 'Inactive',
      'w1': _requiredDouble(b['winnerShare1'], 'Winner share 1'),
      'w2': _requiredDouble(b['winnerShare2'], 'Winner share 2'),
      'w3': _requiredDouble(b['winnerShare3'], 'Winner share 3'),
      'as': club['adminShare'],
      'ms': club['managerShare'],
      'now': nowUtc(),
    },
  );
  return withId(group!);
}

// GET /api/groups/match/:matchId
Future<dynamic> getGroupsByMatch(Req req) async {
  final groups = await Db.pool.rows(
    'SELECT * FROM "Group" WHERE match = @m ORDER BY "createdAt" DESC',
    {'m': req.params['matchId']},
  );
  return _groupsWithMatch(groups);
}

// GET /api/groups/:id
Future<dynamic> getGroupById(Req req) async {
  final group = await Db.pool.row('SELECT * FROM "Group" WHERE id = @id', {'id': req.params['id']});
  if (group == null) fail('Group not found', 404);
  return (await _groupsWithMatch([group])).first;
}

Future<(Map<String, dynamic>, Map<String, dynamic>)> _ownedGroup(Req req) async {
  final group = await Db.pool.row('SELECT * FROM "Group" WHERE id = @id', {'id': req.params['id']});
  if (group == null) fail('Group not found', 404);
  final match = await findMatch(Db.pool, group['match'] as String);
  if (match == null) fail('Match not found', 404);
  assertMatchOwnership(req.me, match);
  return (group, match);
}

// PUT /api/groups/:id
Future<dynamic> updateGroup(Req req) async {
  final (group, match) = await _ownedGroup(req);
  final b = req.body;
  _checkBiddingIncrement(b);
  final club = await Db.pool.row('SELECT * FROM "Club" WHERE id = @id', {'id': match['club']});

  double pick(String key) =>
      b.containsKey(key) ? _requiredDouble(b[key], key) : group[key] as double;

  final updated = await Db.pool.row(
    'UPDATE "Group" SET "betType" = @type, "betAmount" = @amount:float8, "minimumIncrement" = @inc:float8, '
    'status = @status, "winnerShare1" = @w1:float8, "winnerShare2" = @w2:float8, "winnerShare3" = @w3:float8, '
    '"adminShare" = @as:float8, "managerShare" = @ms:float8 WHERE id = @id RETURNING *',
    {
      'id': group['id'],
      'type': b.containsKey('betType') ? str(b['betType']) : group['betType'],
      'amount': pick('betAmount'),
      'inc': b['betType'] == 'Bidding Method' ? toDouble(b['minimumIncrement']) : null,
      'status': b.containsKey('status') ? str(b['status']) : group['status'],
      'w1': pick('winnerShare1'),
      'w2': pick('winnerShare2'),
      'w3': pick('winnerShare3'),
      'as': club?['adminShare'] ?? group['adminShare'],
      'ms': club?['managerShare'] ?? group['managerShare'],
    },
  );
  return withId(updated!);
}

// DELETE /api/groups/:id
Future<dynamic> deleteGroup(Req req) async {
  final (group, _) = await _ownedGroup(req);
  final id = group['id'] as String;
  final (refundedBets, totalRefunded) = await Db.tx((tx) async {
    final refund = await refundOpenBets(
      tx,
      column: 'group',
      value: id,
      description: 'Refund for open bet(s) on a deleted group',
    );
    await tx.exec('DELETE FROM "Bet" WHERE "group" = @id', {'id': id});
    await tx.exec('DELETE FROM "Winners" WHERE "group" = @id', {'id': id});
    await tx.exec('DELETE FROM "Group" WHERE id = @id', {'id': id});
    return refund;
  });
  return {
    'message': 'Group deleted successfully',
    'refundedBets': refundedBets,
    'totalRefunded': totalRefunded,
  };
}

// --- bets ------------------------------------------------------------------

final _combinationPattern = RegExp(r'^[1-7A-G]{3}$');

String _sorted(String combination) => (combination.split('')..sort()).join();

/// Shared core of `placeBet` / `placeMultipleBets`: validates, then debits the
/// wallet, updates the group and records the bets in one transaction.
Future<Map<String, dynamic>> _placeBets(Req req, List<String> combinations) async {
  final b = req.body;
  final userId = req.meId;
  final pool = Db.pool;

  final group = await pool.row('SELECT * FROM "Group" WHERE id = @id', {'id': str(b['groupId'])});
  if (group == null) fail('Group not found', 404);
  final user = await findUser(pool, userId);
  if (user == null) fail('User not found', 404);

  final amount = toDouble(b['betAmount']);
  if (amount == null || amount.isNaN || amount <= 0) {
    fail('Bet amount must be a positive number');
  }
  final totalAmount = amount * combinations.length;
  final credits = user['credits'] as double;
  if (credits < totalAmount) {
    fail(combinations.length == 1
        ? 'Insufficient credits'
        : 'Insufficient credits. You need RS${_n(totalAmount)} but only have RS${_n(credits)}');
  }

  final match = await findMatch(pool, str(b['matchId']) ?? '');
  if (match == null) fail('Match not found', 404);

  // betPolicy.validateBetContext
  if (amount != group['betAmount']) fail('Bet amount must equal the configured group amount');
  if (group['match'] != match['id']) fail('Betting group does not belong to the selected match');
  if (group['status'] != 'Active') fail('Betting group is not active');
  if (match['status'] != 'Active') fail('Match is not active for betting');
  if (user['userType'] != 'Member' || user['memberOf'] == null || user['memberOf'] != match['club']) {
    fail('Member does not belong to this matchs club', 403);
  }

  for (final c in combinations) {
    if (!_combinationPattern.hasMatch(c)) {
      fail(combinations.length == 1 ? 'Invalid combination' : 'Invalid combination: $c');
    }
  }

  final groupId = group['id'] as String;
  final betType = group['betType'] as String;
  final single = combinations.length == 1;

  return Db.tx((tx) async {
    // Lock the group row so two members can't grab the same First Better
    // combination at once.
    await tx.exec('SELECT id FROM "Group" WHERE id = @id FOR UPDATE', {'id': groupId});
    final fresh = await tx.row('SELECT * FROM "Group" WHERE id = @id', {'id': groupId});
    final existing = await tx.rows(
      'SELECT better, combination FROM "Bet" WHERE "group" = @g',
      {'g': groupId},
    );

    var master = List<String>.from(fresh!['CombinationsMaster'] as List? ?? const []);
    final selected = List<String>.from(fresh['SelectedCombinations'] as List? ?? const []);
    final seen = <String>{};
    final bets = <Map<String, dynamic>>[];

    for (final c in combinations) {
      final norm = _sorted(c);
      if (!seen.add(norm)) fail('Duplicate combination detected: $c');

      if (betType == 'First Better') {
        if (existing.any((e) => _sorted(e['combination'] as String) == norm)) {
          fail(single
              ? 'Combination already taken. Please try another combination.'
              : 'Combination $c already taken. Please try another combination.');
        }
      } else if (betType == 'Multi Better') {
        if (existing.any((e) => e['better'] == userId && _sorted(e['combination'] as String) == norm)) {
          fail(single
              ? 'You have already placed a bet on this combination.'
              : 'You have already placed a bet on combination $c');
        }
      }

      if (betType == 'First Better' && master.contains(norm)) {
        master = master.where((m) => m != norm).toList();
        selected.add(norm);
      }

      bets.add({
        'id': newId(),
        'betAmount': amount,
        'match': match['id'],
        'group': groupId,
        'better': userId,
        'score': 0.0,
        'result': null,
        'combination': c,
        'createdAt': nowUtc(),
      });
    }

    final debited = await tx.row(
      'UPDATE "User" SET credits = credits - @t:float8 WHERE id = @id AND credits >= @t:float8 RETURNING credits',
      {'t': totalAmount, 'id': userId},
    );
    if (debited == null) fail('Insufficient credits');

    await tx.exec(
      'UPDATE "Group" SET "CombinationsMaster" = @m:_text, "SelectedCombinations" = @s:_text, '
      '"totalBetAmount" = "totalBetAmount" + @t:float8 WHERE id = @id',
      {'m': master, 's': selected, 't': totalAmount, 'id': groupId},
    );

    for (final bet in bets) {
      await tx.exec(
        'INSERT INTO "Bet" (id, "betAmount", match, "group", better, score, result, combination, "createdAt") '
        'VALUES (@id, @amount:float8, @match, @group, @better, 0, NULL, @c, @now:timestamp)',
        {
          'id': bet['id'],
          'amount': amount,
          'match': bet['match'],
          'group': groupId,
          'better': userId,
          'c': bet['combination'],
          'now': bet['createdAt'],
        },
      );
    }

    final teams = '${match['team1']} vs ${match['team2']}';
    final txn = await insertTransaction(
      tx,
      user: userId,
      amount: totalAmount,
      type: 'Debit',
      description: single
          ? 'RS ${money(amount)} Bet placed in $teams on ${combinations.first}'
          : 'RS ${money(totalAmount)} Bet placed in $teams on ${combinations.length} combinations',
    );

    return {
      'bets': bets.map(withId).toList(),
      'newBalance': debited['credits'],
      'transactionId': txn['id'],
      'notificationsQueued': true,
    };
  });
}

String _n(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

// POST /api/bets
Future<dynamic> placeBet(Req req) async {
  final combination = str(req.body['combination']) ?? '';
  final data = await _placeBets(req, [combination]);
  final bets = data.remove('bets') as List;
  return {
    'success': true,
    'message': 'Bet placed successfully!',
    'data': {'bet': bets.first, ...data},
  };
}

// POST /api/bets/multiple
Future<dynamic> placeMultipleBets(Req req) async {
  final raw = req.body['combinations'];
  if (raw is! List || raw.isEmpty) fail('At least one combination is required');
  if (raw.length > 5) fail('Maximum 5 combinations allowed per request');
  final combinations = raw.map((c) => c.toString()).toList();
  final data = await _placeBets(req, combinations);
  return {
    'success': true,
    'message': '${combinations.length} bets placed successfully!',
    'data': data,
  };
}

// GET /api/bets/group/:groupId
Future<dynamic> getBetsByGroup(Req req) async {
  final bets = await Db.pool.rows(
    'SELECT b.*, u.id AS "uId", u."firstName" AS "uFirstName", u."lastName" AS "uLastName", '
    'u."phoneNumber" AS "uPhone" FROM "Bet" b LEFT JOIN "User" u ON u.id = b.better WHERE b."group" = @g',
    {'g': req.params['groupId']},
  );
  return bets.map((b) {
    final out = withId(b)
      ..remove('uId')
      ..remove('uFirstName')
      ..remove('uLastName')
      ..remove('uPhone');
    out['better'] = b['uId'] == null
        ? null
        : {
            '_id': b['uId'],
            'firstName': b['uFirstName'],
            'lastName': b['uLastName'],
            'phoneNumber': b['uPhone'],
          };
    return out;
  }).toList();
}

// GET /api/bets/my-bets
Future<dynamic> getMyBets(Req req) async {
  final bets = await Db.pool.rows(
    'SELECT b.*, m.team1 AS "mTeam1", m.team2 AS "mTeam2", g."betType" AS "gBetType" '
    'FROM "Bet" b LEFT JOIN "Match" m ON m.id = b.match LEFT JOIN "Group" g ON g.id = b."group" '
    'WHERE b.better = @u ORDER BY b."createdAt" DESC',
    {'u': req.meId},
  );
  return bets.map((b) {
    final out = withId(b)
      ..remove('mTeam1')
      ..remove('mTeam2')
      ..remove('gBetType');
    out['match'] = b['mTeam1'] == null
        ? null
        : {'_id': b['match'], 'team1': b['mTeam1'], 'team2': b['mTeam2']};
    out['group'] = b['gBetType'] == null ? null : {'_id': b['group'], 'betType': b['gBetType']};
    return out;
  }).toList();
}

// --- winners ---------------------------------------------------------------

// GET /api/winners/group/:groupId
Future<dynamic> getWinnersByGroup(Req req) async {
  final winners = await Db.pool.row(
    'SELECT * FROM "Winners" WHERE "group" = @g LIMIT 1',
    {'g': req.params['groupId']},
  );
  return winners == null ? null : withId(winners);
}

// GET /api/winners/my-winnings
Future<dynamic> getMyWinnings(Req req) async {
  final all = await Db.pool.rows(
    'SELECT w.*, m.team1 AS "mTeam1", m.team2 AS "mTeam2", g."betType" AS "gBetType" '
    'FROM "Winners" w LEFT JOIN "Match" m ON m.id = w.match LEFT JOIN "Group" g ON g.id = w."group" '
    'ORDER BY w."createdAt" DESC',
  );
  bool mine(dynamic list) => list is List && list.any((e) => e is Map && e['user'] == req.meId);
  return all
      .where((w) => mine(w['firstWinners']) || mine(w['secondWinners']) || mine(w['thirdWinners']))
      .map((w) {
    final out = withId(w)
      ..remove('mTeam1')
      ..remove('mTeam2')
      ..remove('gBetType');
    out['match'] = w['mTeam1'] == null
        ? null
        : {'_id': w['match'], 'team1': w['mTeam1'], 'team2': w['mTeam2']};
    out['group'] = w['gBetType'] == null ? null : {'_id': w['group'], 'betType': w['gBetType']};
    return out;
  }).toList();
}
