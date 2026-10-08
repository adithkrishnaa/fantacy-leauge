import '../core.dart';
import '../db.dart';

/// Port of `backend/controllers/clubController.js`.

Future<Map<String, Map<String, dynamic>>> _managersById(List<String> ids) async {
  if (ids.isEmpty) return {};
  final users = await Db.pool.rows(
    'SELECT id, "firstName", "lastName", email, "phoneNumber" FROM "User" WHERE id = ANY(@ids:_text)',
    {'ids': ids},
  );
  return {for (final u in users) u['id'] as String: {...u, '_id': u['id']}};
}

Map<String, dynamic> _withManager(
  Map<String, dynamic> club,
  Map<String, Map<String, dynamic>> managers,
) =>
    {...withId(club), 'user': managers[club['user']]};

// POST /api/clubs
Future<dynamic> addClub(Req req) async {
  final b = req.body;
  const required = [
    'clubName', 'managerFirstName', 'managerLastName', 'managerEmail',
    'countryCode', 'managerPhone', 'managerShare', 'adminShare', 'managerPassword',
  ];
  if (required.any((k) => !truthy(b[k]))) fail('All fields are required.');

  final managerShare = toDouble(b['managerShare']);
  final adminShare = toDouble(b['adminShare']);
  if (managerShare == null || adminShare == null) {
    fail('Manager and admin shares must be numbers');
  }

  final managerPhone = cleanPhone(b['managerPhone']);
  final managerEmail = b['managerEmail'].toString();
  final passwordHash = await hashPassword(b['managerPassword'].toString());

  final club = await Db.tx((tx) async {
    var manager = await tx.row(
      'SELECT * FROM "User" WHERE "phoneNumber" = @p',
      {'p': managerPhone},
    );
    if (manager == null) {
      manager = await tx.row(
        'INSERT INTO "User" (id, "firstName", "lastName", email, "countryCode", "phoneNumber", password, '
        '"userType", credits, "referralCount", "referralEarnings", "createdAt") '
        'VALUES (@id, @first, @last, @email, @cc, @phone, @pw, \'Manager\', 0, 0, 0, @now:timestamp) RETURNING *',
        {
          'id': newId(),
          'first': b['managerFirstName'].toString(),
          'last': b['managerLastName'].toString(),
          'email': managerEmail,
          'cc': b['countryCode'].toString(),
          'phone': managerPhone,
          'pw': passwordHash,
          'now': nowUtc(),
        },
      );
    } else if (manager['userType'] != 'Manager') {
      await tx.exec(
        'UPDATE "User" SET "userType" = \'Manager\' WHERE id = @id',
        {'id': manager['id']},
      );
    }

    return tx.row(
      'INSERT INTO "Club" (id, "clubName", "managerFirstName", "managerLastName", "managerEmail", '
      '"managerPhone", "managerShare", "adminShare", "user", "createdAt") '
      'VALUES (@id, @name, @first, @last, @email, @phone, @ms:float8, @as:float8, @user, @now:timestamp) RETURNING *',
      {
        'id': newId(),
        'name': b['clubName'].toString(),
        'first': b['managerFirstName'].toString(),
        'last': b['managerLastName'].toString(),
        'email': managerEmail,
        'phone': managerPhone,
        'ms': managerShare,
        'as': adminShare,
        'user': manager!['id'],
        'now': nowUtc(),
      },
    );
  });

  return {'message': 'Club added successfully!', 'club': withId(club!)};
}

// GET /api/clubs
Future<dynamic> getClubs(Req req) async {
  final clubs = await Db.pool.rows('SELECT * FROM "Club"');
  final managers = await _managersById(clubs.map((c) => c['user'] as String).toList());
  return clubs.map((c) => _withManager(c, managers)).toList();
}

// GET /api/clubs/:id
Future<dynamic> getClubById(Req req) async {
  final club = await Db.pool.row('SELECT * FROM "Club" WHERE id = @id', {'id': req.params['id']});
  if (club == null) fail('Club not found', 404);
  return _withManager(club, await _managersById([club['user'] as String]));
}

// PUT /api/clubs/:id
Future<dynamic> updateClub(Req req) async {
  final pool = Db.pool;
  final club = await pool.row('SELECT * FROM "Club" WHERE id = @id', {'id': req.params['id']});
  if (club == null) fail('Club not found', 404);

  final b = req.body;
  final managerEmail = truthy(b['managerEmail']) ? b['managerEmail'].toString() : null;

  Map<String, dynamic>? manager;
  if (managerEmail != null) {
    manager = await pool.row('SELECT * FROM "User" WHERE email = @e', {'e': managerEmail});
    manager ??= await pool.row(
      'INSERT INTO "User" (id, "firstName", "lastName", email, "phoneNumber", password, '
      '"userType", credits, "referralCount", "referralEarnings", "createdAt") '
      'VALUES (@id, @first, @last, @email, @phone, @pw, \'Manager\', 0, 0, 0, @now:timestamp) RETURNING *',
      {
        'id': newId(),
        'first': str(b['managerFirstName']) ?? '',
        'last': str(b['managerLastName']) ?? '',
        'email': managerEmail,
        'phone': cleanPhone(b['managerPhone']),
        'pw': await hashPassword('defaultpassword'),
        'now': nowUtc(),
      },
    );
  }

  double pick(String key) =>
      truthy(b[key]) ? (toDouble(b[key]) ?? club[key] as double) : club[key] as double;

  final updated = await pool.row(
    'UPDATE "Club" SET "clubName" = @name, "managerFirstName" = @first, "managerLastName" = @last, '
    '"managerEmail" = @email, "managerPhone" = @phone, "managerShare" = @ms:float8, '
    '"adminShare" = @as:float8, "user" = @user WHERE id = @id RETURNING *',
    {
      'id': club['id'],
      'name': truthy(b['clubName']) ? b['clubName'].toString() : club['clubName'],
      'first': manager?['firstName'] ?? club['managerFirstName'],
      'last': manager?['lastName'] ?? club['managerLastName'],
      'email': manager?['email'] ?? club['managerEmail'],
      'phone': manager?['phoneNumber'] ?? club['managerPhone'],
      'ms': pick('managerShare'),
      'as': pick('adminShare'),
      'user': manager?['id'] ?? club['user'],
    },
  );
  return {'message': 'Club updated successfully!', 'updatedClub': withId(updated!)};
}

// DELETE /api/clubs/:id
Future<dynamic> deleteClub(Req req) async {
  final pool = Db.pool;
  final club = await pool.row('SELECT * FROM "Club" WHERE id = @id', {'id': req.params['id']});
  if (club == null) fail('Club not found', 404);

  final counts = await pool.row(
    'SELECT (SELECT count(*) FROM "Match" WHERE club = @id)::int AS matches, '
    '(SELECT count(*) FROM "User" WHERE "memberOf" = @id)::int AS members',
    {'id': club['id']},
  );
  final matchCount = counts!['matches'] as int;
  final memberCount = counts['members'] as int;
  if (matchCount > 0 || memberCount > 0) {
    final parts = [
      if (matchCount > 0) '$matchCount match${matchCount == 1 ? '' : 'es'}',
      if (memberCount > 0) '$memberCount member${memberCount == 1 ? '' : 's'}',
    ];
    fail(
      'Cannot delete "${club['clubName']}" while it still has ${parts.join(' and ')}. '
      'Remove them first, then delete the club.',
      409,
    );
  }

  await pool.exec('DELETE FROM "Club" WHERE id = @id', {'id': club['id']});
  return {'message': 'Club deleted successfully'};
}
