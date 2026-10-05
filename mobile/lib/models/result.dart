import 'json_utils.dart';

/// Per-over (or per-slot) scores for both teams of a match.
class MatchResult {
  const MatchResult({
    required this.id,
    required this.matchId,
    this.team1Scores = const [],
    this.team2Scores = const [],
    this.createdAt,
  });

  final String id;
  final String matchId;
  final List<int> team1Scores;
  final List<int> team2Scores;
  final DateTime? createdAt;

  int get team1Total => team1Scores.fold(0, (a, b) => a + b);
  int get team2Total => team2Scores.fold(0, (a, b) => a + b);

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
        id: idOf(json),
        matchId: relationId(json['match']) ?? '',
        team1Scores: asIntList(json['team1Scores']),
        team2Scores: asIntList(json['team2Scores']),
        createdAt: asDate(json['createdAt']),
      );
}
