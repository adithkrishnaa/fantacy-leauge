import '../models/user.dart';
import 'api_client.dart';

/// Everything under `/api/users` that relates to the signed-in identity.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  /// `POST /api/users/login` -> `{_id, firstName, email, userType, credits, token}`
  ///
  /// Persists the returned JWT so subsequent requests are authenticated.
  Future<AppUser> login({
    required String phoneNumber,
    required String password,
  }) async {
    final data = await _api.post(
      '/users/login',
      body: {'phoneNumber': phoneNumber.trim(), 'password': password},
    ) as Map<String, dynamic>;

    await _api.setToken(data['token']?.toString());
    return AppUser.fromJson(data);
  }

  /// `POST /api/users/register` -> `{_id, email, userType, token}`
  ///
  /// Note the login payload is richer than this one, so callers should follow
  /// up with [profile] to get credits and club membership.
  Future<AppUser> register({
    required String firstName,
    required String lastName,
    String? email,
    String countryCode = '+91',
    required String phoneNumber,
    required String password,
    String? referralCode,
  }) async {
    final data = await _api.post('/users/register', body: {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'countryCode': countryCode,
      'phoneNumber': phoneNumber.trim(),
      'password': password,
      if (referralCode != null && referralCode.trim().isNotEmpty)
        'referralCode': referralCode.trim(),
    }) as Map<String, dynamic>;

    await _api.setToken(data['token']?.toString());
    return AppUser.fromJson(data);
  }

  /// `GET /api/users/profile` — the full row plus populated `memberOf` club.
  Future<AppUser> profile() async {
    final data = await _api.get('/users/profile') as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  /// `PUT /api/users/change-password`
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.put('/users/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// `GET /api/users/referral-stats`
  Future<ReferralStats> referralStats() async {
    final data = await _api.get('/users/referral-stats') as Map<String, dynamic>;
    return ReferralStats.fromJson(data);
  }

  Future<void> logout() => _api.setToken(null);
}
