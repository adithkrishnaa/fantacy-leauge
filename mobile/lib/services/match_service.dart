import '../models/match.dart';
import '../models/result.dart';
import 'api_client.dart';

/// `/api/matches` and `/api/results`.
class MatchService {
  MatchService(this._api);

  final ApiClient _api;

  /// `GET /api/matches` — manager sees their club's matches, admin sees all.
  Future<List<GameMatch>> list() async {
    final data = await _api.get('/matches');
    return _matches(data);
  }

  /// `GET /api/matches/club/:clubId` — used by members to see their club's
  /// fixtures.
  Future<List<GameMatch>> byClub(String clubId) async {
    final data = await _api.get('/matches/club/$clubId');
    return _matches(data);
  }

  /// `GET /api/matches/:id`
  Future<GameMatch> byId(String id) async {
    final data = await _api.get('/matches/$id') as Map<String, dynamic>;
    return GameMatch.fromJson(data);
  }

  /// `POST /api/matches` (manager) or `POST /api/matches/Admin-club/:clubId`
  /// (admin, which picks the club explicitly).
  Future<GameMatch> create({
    required String team1,
    required String team2,
    required DateTime dateTime,
    String status = 'Inactive',
    String? clubId,
  }) async {
    final path = clubId == null ? '/matches' : '/matches/Admin-club/$clubId';
    final data = await _api.post(path, body: {
      'team1': team1.trim(),
      'team2': team2.trim(),
      'dateTime': dateTime.toUtc().toIso8601String(),
      'status': status,
    }) as Map<String, dynamic>;
    return GameMatch.fromJson(data);
  }

  /// `PUT /api/matches/:id`
  Future<GameMatch> update(
    String id, {
    String? team1,
    String? team2,
    DateTime? dateTime,
    String? status,
  }) async {
    final data = await _api.put('/matches/$id', body: {
      if (team1 != null) 'team1': team1.trim(),
      if (team2 != null) 'team2': team2.trim(),
      if (dateTime != null) 'dateTime': dateTime.toUtc().toIso8601String(),
      'status': ?status,
    }) as Map<String, dynamic>;
    return GameMatch.fromJson(data);
  }

  /// `DELETE /api/matches/:id`
  Future<void> remove(String id) => _api.delete('/matches/$id');

  /// `PUT /api/matches/:id/update-players`
  ///
  /// Player maps are slot -> name, matching the `Team1Players` JSON column.
  Future<GameMatch> updatePlayers(
    String id, {
    required Map<String, String> team1Players,
    required Map<String, String> team2Players,
  }) async {
    final data = await _api.put('/matches/$id/update-players', body: {
      'team1Players': team1Players,
      'team2Players': team2Players,
    }) as Map<String, dynamic>;
    return GameMatch.fromJson(data);
  }

  /// `POST /api/matches/:matchId/approve-credits`
  ///
  /// Settles the match: computes winners and pays out credits. Irreversible,
  /// so the UI confirms before calling this.
  Future<void> approveCredits(String matchId) =>
      _api.post('/matches/$matchId/approve-credits');

  // --- Results -----------------------------------------------------------

  /// `GET /api/results/:id`
  Future<MatchResult> result(String resultId) async {
    final data = await _api.get('/results/$resultId') as Map<String, dynamic>;
    return MatchResult.fromJson(data);
  }

  /// `POST /api/results` — also flips the match to `Ongoing`.
  Future<MatchResult> addResult({
    required String matchId,
    required List<int> team1Scores,
    required List<int> team2Scores,
  }) async {
    final data = await _api.post('/results', body: {
      'matchId': matchId,
      'team1Scores': team1Scores,
      'team2Scores': team2Scores,
    }) as Map<String, dynamic>;
    return MatchResult.fromJson(data);
  }

  /// `PUT /api/results/:id`
  Future<MatchResult> updateResult(
    String resultId, {
    required String matchId,
    required List<int> team1Scores,
    required List<int> team2Scores,
  }) async {
    final data = await _api.put('/results/$resultId', body: {
      'matchId': matchId,
      'team1Scores': team1Scores,
      'team2Scores': team2Scores,
    }) as Map<String, dynamic>;
    return MatchResult.fromJson(data);
  }

  List<GameMatch> _matches(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => GameMatch.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map) {
      final list = data['matches'] ?? data['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => GameMatch.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return const [];
  }
}
