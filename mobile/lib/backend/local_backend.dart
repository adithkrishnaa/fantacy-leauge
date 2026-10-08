import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../services/api_client.dart';
import 'core.dart';
import 'db.dart';
import 'handlers/betting.dart' as betting;
import 'handlers/clubs.dart' as clubs;
import 'handlers/matches.dart' as matches;
import 'handlers/transactions.dart' as transactions;
import 'handlers/users.dart' as users;

/// Role sets, mirroring `middleware/authMiddleware.js`.
const _admin = {'Admin'};
const _member = {'Member'};
const _managerOrAdmin = {'Manager', 'Admin'};
const _anyRole = {'Manager', 'Admin', 'Member'};

class _Route {
  const _Route(this.method, this.pattern, this.handler, {this.roles, this.public = false});

  final String method;
  final String pattern;
  final Handler handler;

  /// null = any signed-in user (plain `protect`).
  final Set<String>? roles;
  final bool public;

  Map<String, String>? match(String method, List<String> segments) {
    if (method != this.method) return null;
    final parts = pattern.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].startsWith(':')) {
        params[parts[i].substring(1)] = Uri.decodeComponent(segments[i]);
      } else if (parts[i] != segments[i]) {
        return null;
      }
    }
    return params;
  }
}

/// The Express route table (`backend/routes/*.js`), in registration order.
final _routes = <_Route>[
  // users
  _Route('POST', '/users/register', users.registerUser, public: true),
  _Route('POST', '/users/login', users.loginUser, public: true),
  _Route('GET', '/users', users.getUsers, roles: _admin),
  _Route('POST', '/users/add-member', users.addMember, roles: _managerOrAdmin),
  _Route('POST', '/users/add-member/:clubId', users.adminAddMember, roles: _admin),
  _Route('POST', '/users/register-member', users.registerMember, roles: _managerOrAdmin),
  _Route('POST', '/users/register-member/:clubId', users.adminRegisterMember, roles: _admin),
  _Route('GET', '/users/members', users.getMembers, roles: _managerOrAdmin),
  _Route('GET', '/users/members/:clubId', users.getMembersByClub, roles: _admin),
  _Route('PUT', '/users/add-credit/:id', users.addCredit, roles: _managerOrAdmin),
  _Route('PUT', '/users/deduct-credit/:id', users.deductCredit, roles: _managerOrAdmin),
  _Route('PUT', '/users/remove-member/:id', users.removeMember, roles: _managerOrAdmin),
  _Route('GET', '/users/profile', users.getUserProfile),
  _Route('GET', '/users/userdetails/:id', users.getUserById, roles: _anyRole),
  _Route('PUT', '/users/change-password', users.changePassword),
  _Route('GET', '/users/referral/:code', users.getUserByReferralCode, public: true),
  _Route('GET', '/users/referral-stats', users.getReferralStats),
  _Route('POST', '/users/send-whatsapp', users.sendWhatsAppInvite),

  // clubs
  _Route('POST', '/clubs', clubs.addClub, roles: _admin),
  _Route('GET', '/clubs', clubs.getClubs, roles: _managerOrAdmin),
  _Route('GET', '/clubs/:id', clubs.getClubById, roles: _managerOrAdmin),
  _Route('PUT', '/clubs/:id', clubs.updateClub, roles: _admin),
  _Route('DELETE', '/clubs/:id', clubs.deleteClub, roles: _admin),

  // matches
  _Route('POST', '/matches', matches.addMatch, roles: _managerOrAdmin),
  _Route('GET', '/matches', matches.getMatches, roles: _managerOrAdmin),
  _Route('GET', '/matches/:id', matches.getMatchById, roles: _anyRole),
  _Route('PUT', '/matches/:id', matches.updateMatch, roles: _managerOrAdmin),
  _Route('DELETE', '/matches/:id', matches.deleteMatch, roles: _managerOrAdmin),
  _Route('POST', '/matches/Admin-club/:clubId', matches.addMatch, roles: _admin),
  _Route('GET', '/matches/club/:clubId', matches.getMatchesByClub, roles: _anyRole),
  _Route('POST', '/matches/:matchId/approve-credits', matches.approveCredits, roles: _managerOrAdmin),
  _Route('PUT', '/matches/:id/update-players', matches.updatePlayers, roles: _managerOrAdmin),

  // groups
  _Route('POST', '/groups', betting.createGroup, roles: _managerOrAdmin),
  _Route('GET', '/groups/match/:matchId', betting.getGroupsByMatch, roles: _anyRole),
  _Route('GET', '/groups/:id', betting.getGroupById, roles: _anyRole),
  _Route('PUT', '/groups/:id', betting.updateGroup, roles: _managerOrAdmin),
  _Route('DELETE', '/groups/:id', betting.deleteGroup, roles: _managerOrAdmin),

  // bets
  _Route('POST', '/bets', betting.placeBet, roles: _member),
  _Route('POST', '/bets/multiple', betting.placeMultipleBets, roles: _member),
  _Route('GET', '/bets/group/:groupId', betting.getBetsByGroup, roles: _anyRole),
  _Route('GET', '/bets/my-bets', betting.getMyBets, roles: _member),

  // results
  _Route('POST', '/results', matches.addResult, roles: _managerOrAdmin),
  _Route('PUT', '/results/:id', matches.updateResult, roles: _managerOrAdmin),
  _Route('GET', '/results/:id', matches.getResultById, roles: _managerOrAdmin),

  // winners
  _Route('GET', '/winners/my-winnings', betting.getMyWinnings, roles: _member),
  _Route('GET', '/winners/group/:groupId', betting.getWinnersByGroup, roles: _anyRole),

  // transactions
  _Route('POST', '/transactions', transactions.addTransaction, roles: _admin),
  _Route('GET', '/transactions/:userId', transactions.getTransactionsByUser),
  _Route('DELETE', '/transactions/:id', transactions.deleteTransaction, roles: _admin),
];

/// Runs the backend in-process: takes the same (method, path, body) the HTTP
/// client would send and returns what Express would have responded with.
class LocalBackend {
  LocalBackend._();

  static final LocalBackend instance = LocalBackend._();

  /// Whether requests trigger the match-status sweep (the only write that
  /// happens outside an explicit action). Tests turn it off.
  static bool sweepMatchStatuses = true;

  Future<dynamic> handle(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final segments = Uri.parse(path).pathSegments.where((s) => s.isNotEmpty).toList();
    for (final route in _routes) {
      final params = route.match(method, segments);
      if (params == null) continue;
      try {
        if (sweepMatchStatuses) unawaited(matches.updateMatchStatuses());
        final user = route.public ? null : await _authenticate(token, route.roles);
        final req = Req(
          params: params,
          body: body is Map ? jsonify(body) as Map<String, dynamic> : const {},
          user: user,
        );
        return jsonify(await route.handler(req));
      } on ApiException {
        rethrow;
      } catch (e) {
        throw _translate(e);
      }
    }
    throw ApiException('Not found: $method $path', statusCode: 404);
  }

  /// `protect` + the role middleware.
  Future<Map<String, dynamic>> _authenticate(String? token, Set<String>? roles) async {
    if (token == null || !token.startsWith(users.tokenPrefix)) {
      fail('Not authorized, no token', 401);
    }
    final user = await findUser(Db.pool, token.substring(users.tokenPrefix.length));
    if (user == null) fail('User not found', 401);
    if (roles != null && !roles.contains(user['userType'])) {
      fail('Access denied.', 403);
    }
    return {...user, '_id': user['id']}..remove('password');
  }

  ApiException _translate(Object e) {
    if (e is ServerException) {
      if (e.code == '23505') {
        final detail = e.detail ?? '';
        if (detail.contains('phoneNumber')) return ApiException('Phone number already exists', statusCode: 400);
        if (detail.contains('email')) return ApiException('Email already exists', statusCode: 400);
        return ApiException('That record already exists', statusCode: 400);
      }
      if (e.code == '23503') {
        return ApiException('This record is still referenced by other data', statusCode: 409);
      }
      return ApiException(e.message, statusCode: 500);
    }
    if (e is SocketException || e is TimeoutException || e is PgException) {
      return ApiException('Cannot reach the database. Check your internet connection.', statusCode: 503);
    }
    return ApiException(e.toString(), statusCode: 500);
  }
}
