import 'json_utils.dart';

/// A fixture between two teams.
///
/// `Team1Players` / `Team2Players` are free-form JSON on the Prisma model. In
/// practice the frontend writes a map of slot -> player name, so we normalise
/// to `Map<String, String>` and tolerate a bare list.
class GameMatch {
  const GameMatch({
    required this.id,
    required this.team1,
    required this.team2,
    this.dateTime,
    this.status = 'Inactive',
    this.clubId,
    this.clubName,
    this.managerId,
    this.prizeShareStatus = false,
    this.resultId,
    this.team1Players = const {},
    this.team2Players = const {},
    this.createdAt,
  });

  final String id;
  final String team1;
  final String team2;
  final DateTime? dateTime;
  final String status;
  final String? clubId;
  final String? clubName;
  final String? managerId;
  final bool prizeShareStatus;
  final String? resultId;
  final Map<String, String> team1Players;
  final Map<String, String> team2Players;
  final DateTime? createdAt;

  String get title => '$team1 vs $team2';

  bool get isActive => status == 'Active';
  bool get isCompleted => status == 'Completed';

  factory GameMatch.fromJson(Map<String, dynamic> json) {
    final club = json['club'] ?? json['Club'];
    return GameMatch(
      id: idOf(json),
      team1: asString(json['team1']),
      team2: asString(json['team2']),
      dateTime: asDate(json['dateTime']),
      status: asString(json['status'], 'Inactive'),
      clubId: relationId(club),
      clubName: club is Map ? asStringOrNull(club['clubName']) : null,
      managerId: relationId(json['manager']),
      prizeShareStatus: asBool(json['prizeShareStatus']),
      resultId: relationId(json['result']),
      team1Players: _players(json['Team1Players']),
      team2Players: _players(json['Team2Players']),
      createdAt: asDate(json['createdAt']),
    );
  }

  static Map<String, String> _players(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), asString(v)));
    }
    if (value is List) {
      return {
        for (var i = 0; i < value.length; i++)
          (i + 1).toString(): asString(value[i]),
      };
    }
    return const {};
  }
}
