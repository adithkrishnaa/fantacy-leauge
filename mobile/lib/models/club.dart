import 'json_utils.dart';

/// A club. Managers own one club; members belong to one via `memberOf`.
class Club {
  const Club({
    required this.id,
    required this.clubName,
    this.managerFirstName = '',
    this.managerLastName = '',
    this.managerEmail = '',
    this.managerPhone = '',
    this.managerShare = 0,
    this.adminShare = 0,
    this.userId,
    this.createdAt,
  });

  final String id;
  final String clubName;
  final String managerFirstName;
  final String managerLastName;
  final String managerEmail;
  final String managerPhone;
  final double managerShare;
  final double adminShare;
  final String? userId;
  final DateTime? createdAt;

  String get managerName => '$managerFirstName $managerLastName'.trim();

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: idOf(json),
        clubName: asString(json['clubName']),
        managerFirstName: asString(json['managerFirstName']),
        managerLastName: asString(json['managerLastName']),
        managerEmail: asString(json['managerEmail']),
        managerPhone: asString(json['managerPhone']),
        managerShare: asDouble(json['managerShare']),
        adminShare: asDouble(json['adminShare']),
        userId: relationId(json['user']),
        createdAt: asDate(json['createdAt']),
      );
}
