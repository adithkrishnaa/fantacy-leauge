import 'package:postgres/postgres.dart';

import '../core.dart';
import '../db.dart';

/// Ports of `backend/controllers/matchController.js` and
/// `resultController.js`, plus `scripts/matchStatusUpdater.js`.

DateTime? _lastStatusSweep;

/// Flips matches whose start time has passed to `Ongoing`. The server runs
/// this every minute; here it runs at most once a minute, before requests.
Future<void> updateMatchStatuses() async {
  final now = DateTime.now();
  if (_lastStatusSweep != null &&
      now.difference(_lastStatusSweep!) < const Duration(minutes: 1)) {
    return;
  }
  _lastStatusSweep = now;
  try {
    await Db.pool.exec(
      'UPDATE "Match" SET status = \'Ongoing\' '
      'WHERE "dateTime" <= @now:timestamp AND status NOT IN (\'Ongoing\', \'Announced\')',
      {'now': nowUtc()},
    );
  } catch (_) {
    _lastStatusSweep = null; // retry on the next request
  }
}

Future<List<Map<String, dynamic>>> _withClub(List<Map<String, dynamic>> matches) async {
  final ids = matches.map((m) => m['club'] as String).toSet().toList();
  final clubs = ids.isEmpty
      ? <Map<String, dynamic>>[]
      : await Db.pool.rows(
          'SELECT id, "clubName" FROM "Club" WHERE id = ANY(@ids:_text)',
          {'ids': ids},
        );
  final byId = {for (final c in clubs) c['id']: c};
  return matches.map((m) {
    final club = byId[m['club']];
    return {
      ...withId(m),
      'club': club == null ? null : {'_id': club['id'], 'clubName': club['clubName']},
    };
  }).toList();
}

DateTime _parseDate(dynamic v) {
  final parsed = v == null ? null : DateTime.tryParse(v.toString());
  if (parsed == null) fail('A valid match date and time is required');
  return parsed.toUtc();
}

// POST /api/matches  and  POST /api/matches/Admin-club/:clubId
Future<dynamic> addMatch(Req req) async {
  final pool = Db.pool;
  Map<String, dynamic>? club;
  String managerId;

  if (req.role == 'Admin') {
    club = await pool.row('SELECT * FROM "Club" WHERE id = @id', {'id': req.params['clubId']});
    if (club == null) fail('Club not found', 404);
    managerId = club['user'] as String;
  } else if (req.role == 'Manager') {
    club = await findClubOfManager(pool, req.meId);
    if (club == null) {
      club = await pool.row(
        'SELECT * FROM "Club" WHERE "managerEmail" = @e OR "managerPhone" = @p LIMIT 1',
        {
          'e': req.me['email'] ?? '___none___',
          'p': req.me['phoneNumber'] ?? '___none___',
        },
      );
      if (club != null) {
        try {
          await pool.exec('UPDATE "Club" SET "user" = @u WHERE id = @id',
              {'u': req.meId, 'id': club['id']});
        } catch (_) {}
      }
    }
    if (club == null) {
      fail('Club not found for this manager. Please contact Admin to assign a club.');
    }
    managerId = req.meId;
  } else {
    fail('Not authorized to add matches', 403);
  }

  final b = req.body;
  final match = await pool.row(
    'INSERT INTO "Match" (id, team1, team2, "dateTime", status, club, manager, "prizeShareStatus", '
    'result, "Team1Players", "Team2Players", "createdAt") '
    'VALUES (@id, @t1, @t2, @dt:timestamp, @status, @club, @manager, false, NULL, '
    '\'{}\'::jsonb, \'{}\'::jsonb, @now:timestamp) RETURNING *',
    {
      'id': newId(),
      't1': str(b['team1']) ?? '',
      't2': str(b['team2']) ?? '',
      'dt': _parseDate(b['dateTime']),
      'status': truthy(b['status']) ? b['status'].toString() : 'Inactive',
      'club': club['id'],
      'manager': managerId,
      'now': nowUtc(),
    },
  );

  final members = await pool.rows(
    'SELECT count(*)::int AS n FROM "User" WHERE "memberOf" = @c',
    {'c': club['id']},
  );
  final memberCount = members.first['n'] as int;

  return {
    'success': true,
    'message': 'Match added and notifications queued successfully!',
    'data': {
      'match': withId(match!),
      'notifications': {
        'totalMembers': memberCount,
        'queuedSuccessfully': memberCount,
        'failedToQueue': 0,
        'messageIds': <String>[],
      },
    },
  };
}

Future<Map<String, dynamic>> _editableMatch(Req req, String verb) async {
  final match = await findMatch(Db.pool, req.params['id']!);
  if (match == null) {
    fail('Match not found or you do not have permission to $verb this match', 404);
  }
  if (req.role != 'Admin' && match['manager'] != req.meId) {
    fail('Not authorized to $verb this match', 403);
  }
  return match;
}

// PUT /api/matches/:id/update-players
Future<dynamic> updatePlayers(Req req) async {
  final match = await _editableMatch(req, 'edit');
  final t1 = req.body['team1Players'];
  final t2 = req.body['team2Players'];
  if (t1 is! Map && t1 is! List || t2 is! Map && t2 is! List) {
    fail('Both team player lists are required', 500);
  }
  final updated = await Db.pool.row(
    'UPDATE "Match" SET "Team1Players" = @t1:jsonb, "Team2Players" = @t2:jsonb WHERE id = @id RETURNING *',
    {'t1': t1, 't2': t2, 'id': match['id']},
  );
  return withId(updated!);
}

// GET /api/matches
Future<dynamic> getMatches(Req req) async {
  final matches = await Db.pool.rows(
    'SELECT * FROM "Match" WHERE manager = @m ORDER BY "createdAt" DESC',
    {'m': req.meId},
  );
  return _withClub(matches);
}

// PUT /api/matches/:id
Future<dynamic> updateMatch(Req req) async {
  final match = await _editableMatch(req, 'edit');
  final b = req.body;
  final updated = await Db.pool.row(
    'UPDATE "Match" SET team1 = @t1, team2 = @t2, "dateTime" = @dt:timestamp, status = @status '
    'WHERE id = @id RETURNING *',
    {
      'id': match['id'],
      't1': b.containsKey('team1') ? str(b['team1']) : match['team1'],
      't2': b.containsKey('team2') ? str(b['team2']) : match['team2'],
      'dt': truthy(b['dateTime']) ? _parseDate(b['dateTime']) : match['dateTime'],
      'status': b.containsKey('status') ? str(b['status']) : match['status'],
    },
  );
  return withId(updated!);
}

// GET /api/matches/:id
Future<dynamic> getMatchById(Req req) async {
  final match = await findMatch(Db.pool, req.params['id']!);
  if (match == null) {
    fail('Match not found or you do not have permission to view this match', 404);
  }
  return (await _withClub([match])).first;
}

/// Refunds every open (unsettled) bet in [where] and returns
/// `(refundedBets, totalRefunded)`. Settled Win/Loss bets were already paid
/// out during prize distribution, so their stakes are not refunded.
Future<(int, double)> refundOpenBets(
  TxSession tx, {
  required String column,
  required String value,
  required String description,
}) async {
  final open = await tx.rows(
    'SELECT better, "betAmount" FROM "Bet" WHERE "$column" = @v AND result IS NULL',
    {'v': value},
  );
  final byUser = <String, double>{};
  for (final bet in open) {
    final user = bet['better'] as String;
    byUser[user] = (byUser[user] ?? 0) + (bet['betAmount'] as double);
  }
  var total = 0.0;
  for (final entry in byUser.entries) {
    if (entry.value <= 0) continue;
    total += entry.value;
    await incrementCredits(tx, entry.key, entry.value);
    await insertTransaction(
      tx,
      user: entry.key,
      amount: entry.value,
      type: 'Credit',
      transactionId: 'REFUND-${newId()}',
      description: description,
    );
  }
  return (open.length, total);
}

// DELETE /api/matches/:id
Future<dynamic> deleteMatch(Req req) async {
  final match = await _editableMatch(req, 'delete');
  final id = match['id'] as String;

  final (refundedBets, totalRefunded) = await Db.tx((tx) async {
    final refund = await refundOpenBets(
      tx,
      column: 'match',
      value: id,
      description:
          'Refund for open bet(s) on deleted match ${match['team1']} vs ${match['team2']}',
    );
    final p = {'id': id};
    await tx.exec('UPDATE "Match" SET result = NULL WHERE id = @id', p);
    await tx.exec('DELETE FROM "Bet" WHERE match = @id', p);
    await tx.exec('DELETE FROM "Winners" WHERE match = @id', p);
    await tx.exec('DELETE FROM "Group" WHERE match = @id', p);
    await tx.exec('DELETE FROM "Result" WHERE match = @id', p);
    await tx.exec('DELETE FROM "Match" WHERE id = @id', p);
    return refund;
  });

  return {
    'message': 'Match and its groups, bets and results were deleted successfully',
    'refundedBets': refundedBets,
    'totalRefunded': totalRefunded,
  };
}

// GET /api/matches/club/:clubId
Future<dynamic> getMatchesByClub(Req req) async {
  final matches = await Db.pool.rows(
    'SELECT * FROM "Match" WHERE club = @c ORDER BY "createdAt" DESC',
    {'c': req.params['clubId']},
  );
  return _withClub(matches);
}

/// Splits the leftover pot between admin and manager by their weights.
(double, double) calculateHouseShares(double remaining, double admin, double manager) {
  if (remaining <= 0) return (0, 0);
  if (admin < 0 || manager < 0 || admin + manager <= 0) {
    fail('Admin and Manager share weights must be configured');
  }
  final adminShare = remaining * admin / (admin + manager);
  return (adminShare, remaining - adminShare);
}

// POST /api/matches/:matchId/approve-credits
Future<dynamic> approveCredits(Req req) async {
  final matchId = req.params['matchId']!;
  final pool = Db.pool;
  final match = await findMatch(pool, matchId);
  if (match == null) fail('Match not found', 404);

  assertMatchOwnership(req.me, match);
  if (match['result'] == null) {
    fail('A saved result is required before approving prize credits');
  }
  if (match['status'] != 'Ongoing') {
    fail('Match results must be announced before approving credits');
  }
  if (match['prizeShareStatus'] == true) {
    fail('Prize already distributed for this match');
  }

  final club = await pool.row('SELECT "clubName" FROM "Club" WHERE id = @id', {'id': match['club']});
  final clubName = club?['clubName'] ?? '';
  final teams = '${match['team1']} vs ${match['team2']}';

  final groups = await pool.rows(
    'SELECT * FROM "Group" WHERE match = @m ORDER BY "createdAt" ASC',
    {'m': matchId},
  );
  final admin = await pool.row('SELECT * FROM "User" WHERE "userType" = \'Admin\' LIMIT 1');
  final manager = await findUser(pool, match['manager'] as String);

  final summary = StringBuffer(
    '🏏 *Match Results Announcement* 🏏\n\n*Club:* $clubName\n*Match:* $teams\n\n📊 *Final Results:*',
  );

  // Every balance change for the match happens in ONE transaction, so a
  // failure part-way never leaves credits half distributed.
  await Db.tx((tx) async {
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final groupId = group['id'] as String;
      final bets = await tx.rows(
        'SELECT b.*, u."firstName" AS "uFirstName", u."lastName" AS "uLastName" '
        'FROM "Bet" b LEFT JOIN "User" u ON u.id = b.better WHERE b."group" = @g',
        {'g': groupId},
      );
      bets.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      // Rank by DISTINCT score so a missing tier stays empty.
      final distinct = bets.map((b) => b['score'] as double).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      double? tier(int n) => distinct.length > n ? distinct[n] : null;
      final scores = [tier(0), tier(1), tier(2)];
      final winners = [
        for (final s in scores)
          s == null ? <Map<String, dynamic>>[] : bets.where((b) => b['score'] == s).toList(),
      ];

      final total = (group['totalBetAmount'] as double?) ?? 0;
      final shares = [group['winnerShare1'], group['winnerShare2'], group['winnerShare3']];
      final prizes = [for (final s in shares) total * ((s as double?) ?? 0) / 100];

      const places = ['1st', '2nd', '3rd'];
      const medals = ['🥇', '🥈', '🥉'];
      summary.write('\n\n🔹 *Group ${i + 1} Results:*');
      for (var t = 0; t < 3; t++) {
        final list = winners[t];
        final per = list.isEmpty ? 0.0 : prizes[t] / list.length;
        final names = list.isEmpty
            ? 'No winners'
            : list
                .map((w) => '${w['uFirstName'] ?? ''} (Combination: ${w['combination']}) - RS ${money(per)}')
                .join('\n       ');
        summary.write('\n${medals[t]} *${places[t]} Place (Score: ${_score(scores[t])}):*\n       $names\n');

        if (list.isNotEmpty && prizes[t] > 0) {
          for (final w in list) {
            await incrementCredits(tx, w['better'] as String, per);
            await insertTransaction(
              tx,
              user: w['better'] as String,
              amount: per,
              type: 'Credit',
              description: 'Winning amount (${places[t]} place) for $teams - group: $groupId',
            );
          }
        }
      }

      final winnerIds = winners.expand((l) => l).map((b) => b['id'] as String).toList();
      final loserIds = bets
          .where((b) => !scores.contains(b['score']))
          .map((b) => b['id'] as String)
          .toList();
      if (winnerIds.isNotEmpty) {
        await tx.exec('UPDATE "Bet" SET result = \'Win\' WHERE id = ANY(@ids:_text)', {'ids': winnerIds});
      }
      if (loserIds.isNotEmpty) {
        await tx.exec('UPDATE "Bet" SET result = \'Loss\' WHERE id = ANY(@ids:_text)', {'ids': loserIds});
      }

      List<Map<String, dynamic>> record(int t) => [
            for (final b in winners[t])
              {
                'user': b['better'],
                'bet': b['id'],
                'score': b['score'],
                'amountWon': prizes[t] / (winners[t].isEmpty ? 1 : winners[t].length),
                'combination': b['combination'],
                'firstName': b['uFirstName'] ?? '',
                'lastName': b['uLastName'] ?? '',
              },
          ];
      await tx.exec(
        'INSERT INTO "Winners" (id, match, "group", "firstWinners", "secondWinners", "thirdWinners", "createdAt") '
        'VALUES (@id, @m, @g, @w1:jsonb, @w2:jsonb, @w3:jsonb, @now:timestamp)',
        {
          'id': newId(),
          'm': matchId,
          'g': groupId,
          'w1': record(0),
          'w2': record(1),
          'w3': record(2),
          'now': nowUtc(),
        },
      );

      final remaining = total - prizes.reduce((a, b) => a + b);
      final adminWeight = (group['adminShare'] as double?) ?? 0;
      final managerWeight = (group['managerShare'] as double?) ?? 0;
      final (adminShare, managerShare) =
          calculateHouseShares(remaining, adminWeight, managerWeight);

      if (adminShare > 0 && admin != null) {
        await incrementCredits(tx, admin['id'] as String, adminShare);
        await insertTransaction(
          tx,
          user: admin['id'] as String,
          amount: adminShare,
          type: 'Credit',
          description: 'Admin Share (weight ${_num(adminWeight)}) for $teams - group: $groupId',
        );
      }
      if (managerShare > 0 && manager != null) {
        await incrementCredits(tx, manager['id'] as String, managerShare);
        await insertTransaction(
          tx,
          user: manager['id'] as String,
          amount: managerShare,
          type: 'Credit',
          description: 'Manager Share (weight ${_num(managerWeight)}) for $teams - group: $groupId',
        );
      }
    }

    // Atomically claim the match; a concurrent payout makes this match 0 rows
    // and rolls this one back.
    final claimed = await tx.exec(
      'UPDATE "Match" SET status = \'Announced\', "prizeShareStatus" = true '
      'WHERE id = @id AND "prizeShareStatus" = false',
      {'id': matchId},
    );
    if (claimed == 0) fail('Prize distribution already completed for this match', 409);
  });

  summary.write(
    '\n\n🎉 *Congratulations to all winners!*\n💰 *Winnings will be credited to your accounts shortly.*\n\n'
    "Thank you for participating in $clubName's fantasy league!",
  );

  return {
    'success': true,
    'message': 'Credits approved and distribution queued successfully',
    'data': {
      'matchId': matchId,
      'prizeDistributionCompleted': true,
      'resultsMessage': summary.toString(),
    },
  };
}

String _score(double? s) => s == null ? '-' : _num(s);

/// Prints whole doubles without a trailing `.0`, as JS would.
String _num(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

// --- results ---------------------------------------------------------------

(List<int>, List<int>) _normalizeScores(dynamic t1, dynamic t2) {
  List<int>? parse(dynamic list) {
    if (list is! List || list.length != 7) return null;
    final out = <int>[];
    for (final v in list) {
      final n = toDouble(v);
      if (n == null || n != n.truncateToDouble() || n < 0) return null;
      out.add(n.toInt());
    }
    return out;
  }

  final a = parse(t1);
  final b = parse(t2);
  if (a == null || b == null) {
    fail('Each team must have exactly seven non-negative integer scores');
  }
  return (a, b);
}

/// Recomputes every bet's score for [matchId]: digits 1-7 index team 1's
/// players, letters A-G index team 2's.
Future<void> _calculateBetScores(Session s, String matchId, List<int> t1, List<int> t2) async {
  final bets = await s.rows(
    'SELECT id, combination FROM "Bet" WHERE match = @m',
    {'m': matchId},
  );
  if (bets.isEmpty) return;
  final ids = <String>[];
  final scores = <double>[];
  for (final bet in bets) {
    var total = 0;
    for (final ch in (bet['combination'] as String).split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        final i = digit - 1;
        if (i >= 0 && i < t1.length) total += t1[i];
      } else if (RegExp('[A-G]').hasMatch(ch)) {
        final i = ch.codeUnitAt(0) - 65;
        if (i < t2.length) total += t2[i];
      }
    }
    ids.add(bet['id'] as String);
    scores.add(total.toDouble());
  }
  await s.exec(
    'UPDATE "Bet" AS b SET score = v.score FROM unnest(@ids:_text, @scores:_float8) AS v(id, score) '
    'WHERE b.id = v.id',
    {'ids': ids, 'scores': scores},
  );
}

// GET /api/results/:id
Future<dynamic> getResultById(Req req) async {
  final result = await Db.pool.row('SELECT * FROM "Result" WHERE id = @id', {'id': req.params['id']});
  if (result == null) fail('Result not found', 404);
  return withId(result);
}

// POST /api/results
Future<dynamic> addResult(Req req) async {
  final match = await findMatch(Db.pool, str(req.body['matchId']) ?? '');
  if (match == null) fail('Match not found', 404);
  assertMatchOwnership(req.me, match);
  final (t1, t2) = _normalizeScores(req.body['team1Scores'], req.body['team2Scores']);

  final result = await Db.tx((tx) async {
    final created = await tx.row(
      'INSERT INTO "Result" (id, match, "team1Scores", "team2Scores", "createdAt") '
      'VALUES (@id, @m, @t1:_int4, @t2:_int4, @now:timestamp) RETURNING *',
      {'id': newId(), 'm': match['id'], 't1': t1, 't2': t2, 'now': nowUtc()},
    );
    await tx.exec(
      'UPDATE "Match" SET result = @r, status = \'Ongoing\' WHERE id = @id',
      {'r': created!['id'], 'id': match['id']},
    );
    await _calculateBetScores(tx, match['id'] as String, t1, t2);
    return created;
  });
  return withId(result);
}

// PUT /api/results/:id
Future<dynamic> updateResult(Req req) async {
  final (t1, t2) = _normalizeScores(req.body['team1Scores'], req.body['team2Scores']);
  final result = await Db.pool.row('SELECT * FROM "Result" WHERE id = @id', {'id': req.params['id']});
  if (result == null) fail('Result not found', 404);
  final match = await findMatch(Db.pool, result['match'] as String);
  if (match == null) fail('Match not found', 404);
  assertMatchOwnership(req.me, match);

  final updated = await Db.tx((tx) async {
    final row = await tx.row(
      'UPDATE "Result" SET "team1Scores" = @t1:_int4, "team2Scores" = @t2:_int4 WHERE id = @id RETURNING *',
      {'t1': t1, 't2': t2, 'id': result['id']},
    );
    await _calculateBetScores(tx, result['match'] as String, t1, t2);
    return row!;
  });
  return withId(updated);
}
