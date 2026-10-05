import 'json_utils.dart';

enum UserRole { admin, manager, member, unknown }

UserRole roleFromString(String? value) {
  switch (value) {
    case 'Admin':
      return UserRole.admin;
    case 'Manager':
      return UserRole.manager;
    case 'Member':
      return UserRole.member;
    default:
      return UserRole.unknown;
  }
}

/// A user of the platform. Mirrors the Prisma `User` model.
///
/// `/api/users/login` returns only a subset (id, firstName, email, userType,
/// credits, token); `/api/users/profile` returns the full row plus a populated
/// `memberOf` club. Both shapes parse through this one factory.
class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.email,
    this.countryCode,
    this.phoneNumber = '',
    required this.role,
    this.credits = 0,
    this.memberOfId,
    this.memberOfName,
    this.referralCode,
    this.referralCount = 0,
    this.referralEarnings = 0,
    this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? countryCode;
  final String phoneNumber;
  final UserRole role;
  final double credits;
  final String? memberOfId;
  final String? memberOfName;
  final String? referralCode;
  final int referralCount;
  final double referralEarnings;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName'.trim();

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isMember => role == UserRole.member;

  /// True once an admin has assigned the member to a club. Members without a
  /// club cannot see matches, so the dashboard shows a waiting state.
  bool get hasClub => (memberOfId ?? '').isNotEmpty;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final memberOf = json['memberOf'];
    return AppUser(
      id: idOf(json),
      firstName: asString(json['firstName']),
      lastName: asString(json['lastName']),
      email: asStringOrNull(json['email']),
      countryCode: asStringOrNull(json['countryCode']),
      phoneNumber: asString(json['phoneNumber']),
      role: roleFromString(asStringOrNull(json['userType'])),
      credits: asDouble(json['credits']),
      memberOfId: relationId(memberOf),
      memberOfName:
          memberOf is Map ? asStringOrNull(memberOf['clubName']) : null,
      referralCode: asStringOrNull(json['referralCode']),
      referralCount: asInt(json['referralCount']),
      referralEarnings: asDouble(json['referralEarnings']),
      createdAt: asDate(json['createdAt']),
    );
  }

  AppUser copyWith({double? credits, String? memberOfId, String? memberOfName}) {
    return AppUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      role: role,
      credits: credits ?? this.credits,
      memberOfId: memberOfId ?? this.memberOfId,
      memberOfName: memberOfName ?? this.memberOfName,
      referralCode: referralCode,
      referralCount: referralCount,
      referralEarnings: referralEarnings,
      createdAt: createdAt,
    );
  }
}

/// Result of `/api/users/referral-stats`.
class ReferralStats {
  const ReferralStats({
    this.referralCode,
    this.referralCount = 0,
    this.referralEarnings = 0,
    this.referredUsers = const [],
  });

  final String? referralCode;
  final int referralCount;
  final double referralEarnings;
  final List<ReferredUser> referredUsers;

  factory ReferralStats.fromJson(Map<String, dynamic> json) => ReferralStats(
        referralCode: asStringOrNull(json['referralCode']),
        referralCount: asInt(json['referralCount']),
        referralEarnings: asDouble(json['referralEarnings']),
        referredUsers: asObjectList(json['referredUsers'])
            .map(ReferredUser.fromJson)
            .toList(),
      );
}

class ReferredUser {
  const ReferredUser({
    required this.firstName,
    required this.lastName,
    this.phoneNumber = '',
    this.createdAt,
  });

  final String firstName;
  final String lastName;
  final String phoneNumber;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName'.trim();

  factory ReferredUser.fromJson(Map<String, dynamic> json) => ReferredUser(
        firstName: asString(json['firstName']),
        lastName: asString(json['lastName']),
        phoneNumber: asString(json['phoneNumber']),
        createdAt: asDate(json['createdAt']),
      );
}
