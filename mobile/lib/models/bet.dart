import 'json_utils.dart';

/// A single wager: three symbols drawn from `[1-7A-G]`.
///
/// The backend compares combinations order-insensitively (it sorts the
/// characters before checking uniqueness), so [canonical] mirrors that.
class Bet {
  const Bet({
    required this.id,
    required this.betAmount,
    required this.matchId,
    required this.groupId,
    required this.betterId,
    this.betterName,
    this.score = 0,
    this.result,
    this.combination = '',
    this.createdAt,
  });

  final String id;
  final double betAmount;
  final String matchId;
  final String groupId;
  final String betterId;
  final String? betterName;
  final double score;
  final String? result;
  final String combination;
  final DateTime? createdAt;

  /// Characters sorted, matching the backend's uniqueness comparison.
  String get canonical => (combination.split('')..sort()).join();

  /// The three symbols, for chip-style rendering.
  List<String> get symbols => combination.split('');

  factory Bet.fromJson(Map<String, dynamic> json) {
    final better = json['better'] ?? json['User'];
    String? name;
    if (better is Map) {
      final first = asString(better['firstName']);
      final last = asString(better['lastName']);
      final joined = '$first $last'.trim();
      if (joined.isNotEmpty) name = joined;
    }
    return Bet(
      id: idOf(json),
      betAmount: asDouble(json['betAmount']),
      matchId: relationId(json['match']) ?? '',
      groupId: relationId(json['group']) ?? '',
      betterId: relationId(better) ?? '',
      betterName: name,
      score: asDouble(json['score']),
      result: asStringOrNull(json['result']),
      combination: asString(json['combination']),
      createdAt: asDate(json['createdAt']),
    );
  }
}

/// Valid symbols for a combination, per the backend regex `^[1-7A-G]{3}$`.
const List<String> kCombinationSymbols = <String>[
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
];

/// Length of a combination, per the same regex.
const int kCombinationLength = 3;
