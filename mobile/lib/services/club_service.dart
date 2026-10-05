import '../models/club.dart';
import '../models/user.dart';
import 'api_client.dart';

/// `/api/clubs` plus the member-management endpoints under `/api/users`.
///
/// Admins operate across all clubs (`.../:clubId` variants); managers operate
/// implicitly on the club they own.
class ClubService {
  ClubService(this._api);

  final ApiClient _api;

  // --- Clubs -------------------------------------------------------------

  /// `GET /api/clubs` (manager or admin)
  Future<List<Club>> list() async {
    final data = await _api.get('/clubs');
    return _clubs(data);
  }

  /// `GET /api/clubs/:id`
  Future<Club> byId(String id) async {
    final data = await _api.get('/clubs/$id') as Map<String, dynamic>;
    return Club.fromJson(data);
  }

  /// `POST /api/clubs` (admin only). Creates the club and its manager account.
  Future<Club> create({
    required String clubName,
    required String managerFirstName,
    required String managerLastName,
    required String managerEmail,
    required String managerPhone,
    required double managerShare,
    required double adminShare,
    String? password,
  }) async {
    final data = await _api.post('/clubs', body: {
      'clubName': clubName.trim(),
      'managerFirstName': managerFirstName.trim(),
      'managerLastName': managerLastName.trim(),
      'managerEmail': managerEmail.trim(),
      'managerPhone': managerPhone.trim(),
      'managerShare': managerShare,
      'adminShare': adminShare,
      if (password != null && password.isNotEmpty) 'password': password,
    }) as Map<String, dynamic>;
    return Club.fromJson(data);
  }

  /// `PUT /api/clubs/:id` (admin only)
  Future<Club> update(
    String id, {
    required String clubName,
    required String managerFirstName,
    required String managerLastName,
    required String managerEmail,
    required String managerPhone,
    required double managerShare,
    required double adminShare,
  }) async {
    final data = await _api.put('/clubs/$id', body: {
      'clubName': clubName.trim(),
      'managerFirstName': managerFirstName.trim(),
      'managerLastName': managerLastName.trim(),
      'managerEmail': managerEmail.trim(),
      'managerPhone': managerPhone.trim(),
      'managerShare': managerShare,
      'adminShare': adminShare,
    }) as Map<String, dynamic>;
    return Club.fromJson(data);
  }

  /// `DELETE /api/clubs/:id` (admin only)
  Future<void> remove(String id) => _api.delete('/clubs/$id');

  // --- Members -----------------------------------------------------------

  /// `GET /api/users/members` — members of the caller's club (manager) or all
  /// members (admin). Admins can scope to a club with [clubId].
  Future<List<AppUser>> members({String? clubId}) async {
    final path = clubId == null ? '/users/members' : '/users/members/$clubId';
    final data = await _api.get(path);
    return _users(data);
  }

  /// `GET /api/users` — every user (admin only).
  Future<List<AppUser>> allUsers() async {
    final data = await _api.get('/users');
    return _users(data);
  }

  /// `GET /api/users/userdetails/:id`
  Future<AppUser> userById(String id) async {
    final data = await _api.get('/users/userdetails/$id') as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  /// Attach an existing member account to a club by phone number.
  ///
  /// `POST /api/users/add-member` (manager) or `.../add-member/:clubId` (admin)
  Future<void> addExistingMember({
    required String phoneNumber,
    String? clubId,
  }) async {
    final path =
        clubId == null ? '/users/add-member' : '/users/add-member/$clubId';
    await _api.post(path, body: {'phoneNumber': phoneNumber.trim()});
  }

  /// Create a brand-new member account inside a club.
  ///
  /// `POST /api/users/register-member` (manager) or `.../:clubId` (admin)
  Future<void> registerMember({
    required String firstName,
    required String lastName,
    String? email,
    String countryCode = '+91',
    required String phoneNumber,
    required String password,
    String? clubId,
  }) async {
    final path = clubId == null
        ? '/users/register-member'
        : '/users/register-member/$clubId';
    await _api.post(path, body: {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'countryCode': countryCode,
      'phoneNumber': phoneNumber.trim(),
      'password': password,
    });
  }

  /// `PUT /api/users/remove-member/:id`
  Future<void> removeMember(String memberId) =>
      _api.put('/users/remove-member/$memberId');

  // --- Credits -----------------------------------------------------------

  /// `PUT /api/users/add-credit/:id` with `{creditAmount}`
  Future<void> addCredit(String memberId, double amount) =>
      _api.put('/users/add-credit/$memberId', body: {'creditAmount': amount});

  /// `PUT /api/users/deduct-credit/:id` with `{creditAmount}`
  Future<void> deductCredit(String memberId, double amount) =>
      _api.put('/users/deduct-credit/$memberId', body: {'creditAmount': amount});

  // --- Parsing -----------------------------------------------------------

  List<Club> _clubs(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Club.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map) {
      final list = data['clubs'] ?? data['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Club.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return const [];
  }

  List<AppUser> _users(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => AppUser.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map) {
      final list = data['members'] ?? data['users'] ?? data['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => AppUser.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return const [];
  }
}
