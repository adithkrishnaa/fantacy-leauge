import 'dart:math';

import 'package:postgres/postgres.dart';

import '../core.dart';
import '../db.dart';

/// Port of `backend/controllers/userController.js`.
///
/// WhatsApp notifications are a no-op on the server too
/// (`services/queueService.js`), so they are simply omitted here.

const _referralReward = 100.0;
final _random = Random.secure();

/// Session token for the embedded backend: the user id, prefixed so it can't
/// be confused with a server-issued JWT.
const tokenPrefix = 'local.';
String tokenFor(String userId) => '$tokenPrefix$userId';

Future<String> _uniqueReferralCode(Session s) async {
  while (true) {
    final code = List.generate(4, (_) => _random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final taken = await s.row(
      'SELECT id FROM "User" WHERE "referralCode" = @code',
      {'code': code},
    );
    if (taken == null) return code;
  }
}

Future<String?> _ensureReferralCode(Session s, Map<String, dynamic> user) async {
  if (user['referralCode'] != null) return user['referralCode'] as String;
  final code = await _uniqueReferralCode(s);
  final updated = await s.exec(
    'UPDATE "User" SET "referralCode" = @code WHERE id = @id AND "referralCode" IS NULL',
    {'code': code, 'id': user['id']},
  );
  if (updated == 1) return code;
  final fresh = await findUser(s, user['id'] as String);
  return fresh?['referralCode'] as String?;
}

Future<Map<String, dynamic>> _insertUser(
  Session s, {
  required String firstName,
  required String lastName,
  String? email,
  String? countryCode,
  required String phoneNumber,
  required String passwordHash,
  String userType = 'Member',
  String? memberOf,
  String? referralCode,
  String? referredBy,
}) async {
  final row = await s.row(
    'INSERT INTO "User" (id, "firstName", "lastName", email, "countryCode", "phoneNumber", password, '
    '"userType", "memberOf", credits, "referralCode", "referredBy", "referralCount", "referralEarnings", "createdAt") '
    'VALUES (@id, @first, @last, @email, @cc, @phone, @pw, @type, @club, 0, @ref, @refBy, 0, 0, @now:timestamp) '
    'RETURNING *',
    {
      'id': newId(),
      'first': firstName,
      'last': lastName,
      'email': email,
      'cc': countryCode,
      'phone': phoneNumber,
      'pw': passwordHash,
      'type': userType,
      'club': memberOf,
      'ref': referralCode,
      'refBy': referredBy,
      'now': nowUtc(),
    },
  );
  return row!;
}

String? _emailOrNull(dynamic v) => truthy(v) ? v.toString() : null;

// POST /api/users/register
Future<dynamic> registerUser(Req req) async {
  final b = req.body;
  final firstName = str(b['firstName']) ?? '';
  final lastName = str(b['lastName']) ?? '';
  final email = _emailOrNull(b['email']);
  final password = str(b['password']) ?? '';
  final referral = str(b['referralCode']);
  final phone = cleanPhone(b['phoneNumber']);
  if (firstName.isEmpty || phone.isEmpty || password.isEmpty) {
    fail('First name, phone number and password are required');
  }

  final pool = Db.pool;
  if (await pool.row('SELECT id FROM "User" WHERE "phoneNumber" = @p', {'p': phone}) != null) {
    fail('Phone number already exists');
  }
  if (email != null &&
      await pool.row('SELECT id FROM "User" WHERE email = @e', {'e': email}) != null) {
    fail('Email already exists');
  }

  String? referrerId;
  if (truthy(referral)) {
    final referrer = await pool.row(
      'SELECT id FROM "User" WHERE "referralCode" = @c AND "userType" = \'Member\'',
      {'c': referral},
    );
    if (referrer == null) fail('Invalid referral code');
    referrerId = referrer['id'] as String;
  }
  final referredBy = referrerId;

  final hash = await hashPassword(password);
  final code = await _uniqueReferralCode(pool);

  final user = await Db.tx((tx) async {
    final created = await _insertUser(
      tx,
      firstName: firstName,
      lastName: lastName,
      email: email,
      countryCode: str(b['countryCode']) ?? '+91',
      phoneNumber: phone,
      passwordHash: hash,
      referralCode: code,
      referredBy: referredBy,
    );
    if (referredBy != null) {
      await tx.exec(
        'UPDATE "User" SET credits = credits + @r:float8, "referralCount" = "referralCount" + 1, '
        '"referralEarnings" = "referralEarnings" + @r:float8 WHERE id = @id',
        {'r': _referralReward, 'id': referredBy},
      );
      final txId = newId();
      await insertTransaction(
        tx,
        id: txId,
        transactionId: 'REFERRAL-$txId',
        user: referredBy,
        amount: _referralReward,
        type: 'Credit',
        description: 'Referral registration reward for ${'$firstName $lastName'.trim()}',
      );
    }
    return created;
  });

  return {
    '_id': user['id'],
    'email': user['email'],
    'userType': user['userType'],
    'token': tokenFor(user['id'] as String),
  };
}

// POST /api/users/login
Future<dynamic> loginUser(Req req) async {
  final phone = cleanPhone(req.body['phoneNumber']);
  final password = str(req.body['password']) ?? '';
  if (phone.isEmpty || password.isEmpty) {
    fail('Please provide phone number and password');
  }
  final user = await Db.pool.row(
    'SELECT * FROM "User" WHERE "phoneNumber" = @p',
    {'p': phone},
  );
  if (user == null || !await checkPassword(password, user['password'] as String)) {
    fail('Invalid phone number or password', 401);
  }
  return {
    '_id': user['id'],
    'firstName': user['firstName'],
    'email': user['email'],
    'userType': user['userType'],
    'credits': user['credits'],
    'token': tokenFor(user['id'] as String),
  };
}

// PUT /api/users/change-password
Future<dynamic> changePassword(Req req) async {
  final user = await findUser(Db.pool, req.meId);
  if (user == null) fail('User not found', 404);
  final current = str(req.body['currentPassword']) ?? '';
  final next = str(req.body['newPassword']) ?? '';
  if (!await checkPassword(current, user['password'] as String)) {
    fail('Current password is incorrect');
  }
  if (next.isEmpty) fail('New password is required');
  await Db.pool.exec(
    'UPDATE "User" SET password = @pw WHERE id = @id',
    {'pw': await hashPassword(next), 'id': req.meId},
  );
  return {'message': 'Password changed successfully'};
}

// GET /api/users
Future<dynamic> getUsers(Req req) async {
  final users = await Db.pool.rows('SELECT * FROM "User" ORDER BY "createdAt" DESC');
  return users.map(publicUser).toList();
}

/// The manager's club, re-linking it by email/phone if the `user` pointer is
/// missing (same fallback as the controller).
Future<Map<String, dynamic>> _clubForManager(Req req) async {
  final pool = Db.pool;
  var club = await findClubOfManager(pool, req.meId);
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
        await pool.exec(
          'UPDATE "Club" SET "user" = @u WHERE id = @id',
          {'u': req.meId, 'id': club['id']},
        );
      } catch (_) {
        // Best effort, as on the server.
      }
    }
  }
  if (club == null) {
    fail('Club not found for this manager. Please contact Admin to assign a club.');
  }
  return club;
}

Future<Map<String, dynamic>> _memberByPhone(dynamic phoneNumber) async {
  final user = await Db.pool.row(
    'SELECT * FROM "User" WHERE "phoneNumber" = @p',
    {'p': cleanPhone(phoneNumber)},
  );
  if (user == null) fail('User not found', 404);
  if (user['userType'] != 'Member') fail('User is not a member');
  return user;
}

// POST /api/users/add-member
Future<dynamic> addMember(Req req) async {
  final user = await _memberByPhone(req.body['phoneNumber']);
  final club = await _clubForManager(req);
  await Db.pool.exec(
    'UPDATE "User" SET "memberOf" = @c WHERE id = @id',
    {'c': club['id'], 'id': user['id']},
  );
  return {'message': 'Member added successfully'};
}

// POST /api/users/add-member/:clubId
Future<dynamic> adminAddMember(Req req) async {
  final user = await _memberByPhone(req.body['phoneNumber']);
  final club = await Db.pool.row(
    'SELECT * FROM "Club" WHERE id = @id',
    {'id': req.params['clubId']},
  );
  if (club == null) fail('Club not found', 404);
  await Db.pool.exec(
    'UPDATE "User" SET "memberOf" = @c WHERE id = @id',
    {'c': club['id'], 'id': user['id']},
  );
  return {
    'message': 'Member added successfully',
    'memberId': user['id'],
    'clubName': club['clubName'],
  };
}

Future<Map<String, dynamic>> _registerInClub(Req req, Map<String, dynamic> club) async {
  final b = req.body;
  final email = _emailOrNull(b['email']);
  final phone = cleanPhone(b['phoneNumber']);
  final password = str(b['password']) ?? '';
  final firstName = str(b['firstName']) ?? '';
  if (firstName.isEmpty || phone.isEmpty || password.isEmpty) {
    fail('First name, phone number and password are required');
  }
  final pool = Db.pool;
  if (email != null &&
      await pool.row('SELECT id FROM "User" WHERE email = @e', {'e': email}) != null) {
    fail('User already exists');
  }
  if (await pool.row('SELECT id FROM "User" WHERE "phoneNumber" = @p', {'p': phone}) != null) {
    fail('Phone number already exists');
  }
  return _insertUser(
    pool,
    firstName: firstName,
    lastName: str(b['lastName']) ?? '',
    email: email,
    countryCode: truthy(b['countryCode']) ? b['countryCode'].toString() : '+91',
    phoneNumber: phone,
    passwordHash: await hashPassword(password),
    referralCode: await _uniqueReferralCode(pool),
    memberOf: club['id'] as String,
  );
}

// POST /api/users/register-member
Future<dynamic> registerMember(Req req) async {
  final club = await findClubOfManager(Db.pool, req.meId);
  if (club == null) fail('Club not found for this manager', 404);
  await _registerInClub(req, club);
  return {'message': 'Member registered successfully'};
}

// POST /api/users/register-member/:clubId
Future<dynamic> adminRegisterMember(Req req) async {
  final club = await Db.pool.row(
    'SELECT * FROM "Club" WHERE id = @id',
    {'id': req.params['clubId']},
  );
  if (club == null) fail('Club not found', 404);
  final user = await _registerInClub(req, club);
  return {
    'message': 'Member registered successfully',
    'memberId': user['id'],
    'clubName': club['clubName'],
  };
}

// GET /api/users/userdetails/:id
Future<dynamic> getUserById(Req req) async {
  final user = await findUser(Db.pool, req.params['id']!);
  if (user == null) fail('User not found', 404);
  return {
    '_id': user['id'],
    'firstName': user['firstName'],
    'email': user['email'],
    'phone': user['phoneNumber'],
    'userType': user['userType'],
    'credits': user['credits'],
  };
}

Future<List<Map<String, dynamic>>> _membersOf(String clubId) async {
  final members = await Db.pool.rows(
    'SELECT * FROM "User" WHERE "memberOf" = @c',
    {'c': clubId},
  );
  return members.map(publicUser).toList();
}

// GET /api/users/members
Future<dynamic> getMembers(Req req) async {
  final club = await findClubOfManager(Db.pool, req.meId);
  if (club == null) fail('Club not found for this manager', 404);
  return _membersOf(club['id'] as String);
}

// GET /api/users/members/:clubId
Future<dynamic> getMembersByClub(Req req) async {
  final club = await Db.pool.row(
    'SELECT * FROM "Club" WHERE id = @id',
    {'id': req.params['clubId']},
  );
  if (club == null) fail('Club not found for this manager', 404);
  return _membersOf(club['id'] as String);
}

Future<Map<String, dynamic>> _ownedMember(Req req) async {
  final member = await findUser(Db.pool, req.params['id']!);
  if (member == null) fail('Member not found', 404);
  final managerClub =
      req.role == 'Manager' ? await findClubOfManager(Db.pool, req.meId) : null;
  assertMemberOwnership(req.me, managerClub, member);
  return member;
}

double _creditAmount(Req req) {
  final amount = toDouble(req.body['creditAmount']);
  if (amount == null || amount.isNaN || amount <= 0) {
    fail('Please enter a valid credit amount');
  }
  return amount;
}

// PUT /api/users/add-credit/:id
Future<dynamic> addCredit(Req req) async {
  final amount = _creditAmount(req);
  final member = await _ownedMember(req);
  final result = await Db.tx((tx) async {
    final updated = await tx.row(
      'UPDATE "User" SET credits = credits + @a:float8 WHERE id = @id RETURNING credits',
      {'a': amount, 'id': member['id']},
    );
    final txn = await insertTransaction(
      tx,
      user: member['id'] as String,
      amount: amount,
      type: 'Credit',
      description: '₹${_jsNumber(req.body['creditAmount'])} Credited by Manager',
    );
    return {'balance': updated!['credits'], 'txn': txn['id']};
  });
  return {
    'message': 'Credit added successfully',
    'newBalance': result['balance'],
    'transactionId': result['txn'],
  };
}

/// How JS would interpolate the raw request value into a template string.
String _jsNumber(dynamic v) {
  if (v is double && v == v.truncateToDouble()) return v.toInt().toString();
  return v.toString();
}

// PUT /api/users/deduct-credit/:id
Future<dynamic> deductCredit(Req req) async {
  final amount = _creditAmount(req);
  final member = await _ownedMember(req);
  final result = await Db.tx((tx) async {
    final updated = await tx.row(
      'UPDATE "User" SET credits = credits - @a:float8 '
      'WHERE id = @id AND credits >= @a:float8 RETURNING credits',
      {'a': amount, 'id': member['id']},
    );
    if (updated == null) fail('Insufficient credits for deduction');
    final txn = await insertTransaction(
      tx,
      user: member['id'] as String,
      amount: amount,
      type: 'Debit',
      transactionId: 'DEDUCT-${DateTime.now().millisecondsSinceEpoch}',
      description: '₹${money(amount)} Debited by Manager',
    );
    return {'balance': updated['credits'], 'txn': txn['id']};
  });
  return {
    'success': true,
    'message': 'Credit deduction processed successfully',
    'data': {
      'memberId': member['id'],
      'amountDeducted': amount,
      'newBalance': result['balance'],
      'transactionId': result['txn'],
      'timestamp': nowUtc().toIso8601String(),
    },
  };
}

// PUT /api/users/remove-member/:id
Future<dynamic> removeMember(Req req) async {
  final member = await _ownedMember(req);
  await Db.pool.exec(
    'UPDATE "User" SET "memberOf" = NULL WHERE id = @id',
    {'id': member['id']},
  );
  return {'message': 'Member removed successfully'};
}

// GET /api/users/profile
Future<dynamic> getUserProfile(Req req) async {
  final user = await findUser(Db.pool, req.meId);
  if (user == null) fail('User not found', 404);
  Map<String, dynamic>? club;
  if (user['memberOf'] != null) {
    club = await Db.pool.row(
      'SELECT id, "clubName" FROM "Club" WHERE id = @id',
      {'id': user['memberOf']},
    );
  }
  return {
    ...publicUser(user),
    'memberOf': club == null
        ? null
        : {'_id': club['id'], 'id': club['id'], 'clubName': club['clubName']},
  };
}

// GET /api/users/referral/:code
Future<dynamic> getUserByReferralCode(Req req) async {
  final user = await Db.pool.row(
    'SELECT * FROM "User" WHERE "referralCode" = @c AND "userType" = \'Member\'',
    {'c': req.params['code']},
  );
  if (user == null) fail('Invalid referral code', 404);
  return {
    'firstName': user['firstName'],
    'lastName': user['lastName'],
    'referralCode': user['referralCode'],
  };
}

// GET /api/users/referral-stats
Future<dynamic> getReferralStats(Req req) async {
  final pool = Db.pool;
  final referred = await pool.rows(
    'SELECT "firstName", "lastName", "createdAt", "phoneNumber" FROM "User" WHERE "referredBy" = @id',
    {'id': req.meId},
  );
  final user = await findUser(pool, req.meId);
  final code = user != null && user['userType'] == 'Member'
      ? await _ensureReferralCode(pool, user)
      : user?['referralCode'];
  return {
    'referralCode': code,
    'referralCount': user?['referralCount'] ?? 0,
    'referralEarnings': user?['referralEarnings'] ?? 0,
    'referredUsers': jsonify(referred),
  };
}

// POST /api/users/send-whatsapp (WhatsApp is disabled server-side too)
Future<dynamic> sendWhatsAppInvite(Req req) async {
  final user = await findUser(Db.pool, req.meId);
  if (user == null) fail('User not found', 404);
  final code = user['userType'] == 'Member'
      ? await _ensureReferralCode(Db.pool, user)
      : user['referralCode'];
  final phone = cleanPhone(req.body['phoneNumber']);
  if (!RegExp(r'^\d{10,15}$').hasMatch(phone)) fail('Invalid phone number format');
  final link = 'https://fantacyleauge.com/register?ref=$code';
  return {
    'success': true,
    'message': 'WhatsApp invitation sent successfully',
    'data': {'phoneNumber': phone, 'referralLink': link},
  };
}
