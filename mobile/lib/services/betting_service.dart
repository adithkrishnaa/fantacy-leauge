import '../models/bet.dart';
import '../models/group.dart';
import '../models/winners.dart';
import 'api_client.dart';

/// `/api/groups`, `/api/bets` and `/api/winners`.
class BettingService {
  BettingService(this._api);

  final ApiClient _api;

  // --- Groups ------------------------------------------------------------

  /// `GET /api/groups/match/:matchId`
  Future<List<BettingGroup>> groupsForMatch(String matchId) async {
    final data = await _api.get('/groups/match/$matchId');
    return _groups(data);
  }

  /// `GET /api/groups/:id`
  Future<BettingGroup> group(String id) async {
    final data = await _api.get('/groups/$id') as Map<String, dynamic>;
    return BettingGroup.fromJson(data);
  }

  /// `POST /api/groups`
  ///
  /// [minimumIncrement] is required by the backend when [betType] is
  /// `Bidding Method` and ignored otherwise.
  Future<BettingGroup> createGroup({
    required String matchId,
    required String betType,
    required double betAmount,
    double? minimumIncrement,
    required double winnerShare1,
    required double winnerShare2,
    required double winnerShare3,
    String status = 'Inactive',
  }) async {
    final data = await _api.post('/groups', body: {
      'matchId': matchId,
      'betType': betType,
      'betAmount': betAmount,
      'minimumIncrement': ?minimumIncrement,
      'winnerShare1': winnerShare1,
      'winnerShare2': winnerShare2,
      'winnerShare3': winnerShare3,
      'status': status,
    }) as Map<String, dynamic>;
    return BettingGroup.fromJson(data);
  }

  /// `PUT /api/groups/:id`
  Future<BettingGroup> updateGroup(
    String id, {
    String? betType,
    double? betAmount,
    double? minimumIncrement,
    double? winnerShare1,
    double? winnerShare2,
    double? winnerShare3,
    String? status,
  }) async {
    final data = await _api.put('/groups/$id', body: {
      'betType': ?betType,
      'betAmount': ?betAmount,
      'minimumIncrement': ?minimumIncrement,
      'winnerShare1': ?winnerShare1,
      'winnerShare2': ?winnerShare2,
      'winnerShare3': ?winnerShare3,
      'status': ?status,
    }) as Map<String, dynamic>;
    return BettingGroup.fromJson(data);
  }

  /// `DELETE /api/groups/:id`
  Future<void> deleteGroup(String id) => _api.delete('/groups/$id');

  // --- Bets --------------------------------------------------------------

  /// `POST /api/bets` — places one wager.
  ///
  /// The backend rejects the bet unless the amount equals the group's
  /// `betAmount`, the group and match are both `Active`, the member belongs to
  /// the match's club, and the combination matches `^[1-7A-G]{3}$`.
  Future<void> placeBet({
    required String matchId,
    required String groupId,
    required double betAmount,
    required String combination,
  }) =>
      _api.post('/bets', body: {
        'matchId': matchId,
        'groupId': groupId,
        'betAmount': betAmount,
        'combination': combination,
      });

  /// `POST /api/bets/multiple` — places several wagers in one request.
  Future<void> placeMultipleBets({
    required String matchId,
    required String groupId,
    required double betAmount,
    required List<String> combinations,
  }) =>
      _api.post('/bets/multiple', body: {
        'matchId': matchId,
        'groupId': groupId,
        'betAmount': betAmount,
        'combinations': combinations,
      });

  /// `GET /api/bets/group/:groupId` — every bet in a group.
  Future<List<Bet>> betsForGroup(String groupId) async {
    final data = await _api.get('/bets/group/$groupId');
    return _bets(data);
  }

  /// `GET /api/bets/my-bets` — the signed-in member's wagers.
  Future<List<Bet>> myBets() async {
    final data = await _api.get('/bets/my-bets');
    return _bets(data);
  }

  // --- Winners -----------------------------------------------------------

  /// `GET /api/winners/group/:groupId` — null until the match is settled.
  Future<GroupWinners?> winnersForGroup(String groupId) async {
    final data = await _api.get('/winners/group/$groupId');
    if (data is Map && data.isNotEmpty) {
      return GroupWinners.fromJson(data.cast<String, dynamic>());
    }
    return null;
  }

  /// `GET /api/winners/my-winnings`
  Future<List<Map<String, dynamic>>> myWinnings() async {
    final data = await _api.get('/winners/my-winnings');
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  // --- Parsing -----------------------------------------------------------

  List<BettingGroup> _groups(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => BettingGroup.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map) {
      final list = data['groups'] ?? data['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => BettingGroup.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return const [];
  }

  List<Bet> _bets(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Bet.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map) {
      final list = data['bets'] ?? data['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Bet.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return const [];
  }
}
