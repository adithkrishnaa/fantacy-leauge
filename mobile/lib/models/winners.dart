import 'json_utils.dart';

/// Winners of a betting group, in three prize tiers.
///
/// `approveCredits` writes the winner arrays with `firstName`/`lastName`
/// already embedded, so no relation lookup is needed to display them.
class GroupWinners {
  const GroupWinners({
    required this.id,
    required this.matchId,
    required this.groupId,
    this.first = const [],
    this.second = const [],
    this.third = const [],
    this.createdAt,
  });

  final String id;
  final String matchId;
  final String groupId;
  final List<WinnerEntry> first;
  final List<WinnerEntry> second;
  final List<WinnerEntry> third;
  final DateTime? createdAt;

  bool get isEmpty => first.isEmpty && second.isEmpty && third.isEmpty;

  factory GroupWinners.fromJson(Map<String, dynamic> json) => GroupWinners(
        id: idOf(json),
        matchId: relationId(json['match']) ?? '',
        groupId: relationId(json['group']) ?? '',
        first: _entries(json['firstWinners']),
        second: _entries(json['secondWinners']),
        third: _entries(json['thirdWinners']),
        createdAt: asDate(json['createdAt']),
      );

  static List<WinnerEntry> _entries(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => WinnerEntry.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }
}

class WinnerEntry {
  const WinnerEntry({
    this.userId,
    this.firstName = '',
    this.lastName = '',
    this.combination = '',
    this.amount = 0,
    this.score = 0,
  });

  final String? userId;
  final String firstName;
  final String lastName;
  final String combination;
  final double amount;
  final double score;

  String get fullName {
    final joined = '$firstName $lastName'.trim();
    return joined.isEmpty ? 'Unknown' : joined;
  }

  factory WinnerEntry.fromJson(Map<String, dynamic> json) => WinnerEntry(
        userId: relationId(json['user'] ?? json['better'] ?? json['userId']),
        firstName: asString(json['firstName']),
        lastName: asString(json['lastName']),
        combination: asString(json['combination']),
        amount: asDouble(json['amount'] ?? json['prize'] ?? json['share']),
        score: asDouble(json['score']),
      );
}
