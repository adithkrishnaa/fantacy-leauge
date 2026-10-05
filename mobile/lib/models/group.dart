import 'json_utils.dart';

/// A betting pool attached to a match.
///
/// `betType` is either `First Better` (each combination can be claimed once,
/// moving from [combinationsMaster] to [selectedCombinations]) or
/// `Multi Better` (many members may hold the same combination, but each member
/// only once).
class BettingGroup {
  const BettingGroup({
    required this.id,
    required this.matchId,
    this.betType = 'First Better',
    this.betAmount = 0,
    this.minimumIncrement,
    this.status = 'Inactive',
    this.totalBetAmount = 0,
    this.winnerShare1 = 0,
    this.winnerShare2 = 0,
    this.winnerShare3 = 0,
    this.adminShare,
    this.managerShare,
    this.combinationsMaster = const [],
    this.selectedCombinations = const [],
    this.createdAt,
  });

  final String id;
  final String matchId;
  final String betType;
  final double betAmount;
  final double? minimumIncrement;
  final String status;
  final double totalBetAmount;
  final double winnerShare1;
  final double winnerShare2;
  final double winnerShare3;
  final double? adminShare;
  final double? managerShare;
  final List<String> combinationsMaster;
  final List<String> selectedCombinations;
  final DateTime? createdAt;

  bool get isActive => status == 'Active';
  bool get isFirstBetter => betType == 'First Better';

  /// Combinations still claimable in a `First Better` group.
  List<String> get availableCombinations => combinationsMaster;

  factory BettingGroup.fromJson(Map<String, dynamic> json) => BettingGroup(
        id: idOf(json),
        matchId: relationId(json['match']) ?? '',
        betType: asString(json['betType'], 'First Better'),
        betAmount: asDouble(json['betAmount']),
        minimumIncrement: json['minimumIncrement'] == null
            ? null
            : asDouble(json['minimumIncrement']),
        status: asString(json['status'], 'Inactive'),
        totalBetAmount: asDouble(json['totalBetAmount']),
        winnerShare1: asDouble(json['winnerShare1']),
        winnerShare2: asDouble(json['winnerShare2']),
        winnerShare3: asDouble(json['winnerShare3']),
        adminShare:
            json['adminShare'] == null ? null : asDouble(json['adminShare']),
        managerShare: json['managerShare'] == null
            ? null
            : asDouble(json['managerShare']),
        combinationsMaster: asStringList(json['CombinationsMaster']),
        selectedCombinations: asStringList(json['SelectedCombinations']),
        createdAt: asDate(json['createdAt']),
      );
}
