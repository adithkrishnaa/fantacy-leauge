import 'package:flutter/foundation.dart';

import '../models/user.dart';

import '../services/services.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Holds the signed-in user and drives which dashboard the app shows.
class AuthState extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;
  bool get busy => _busy;

  UserRole get role => _user?.role ?? UserRole.unknown;
  double get credits => _user?.credits ?? 0;

  /// Restores a persisted session on cold start.
  ///
  /// A stored token can be expired or belong to a deleted user, so we verify
  /// it against `/users/profile` before trusting it.
  Future<void> restore() async {
    await Services.api.loadToken();
    final token = Services.api.token;
    if (token == null || token.isEmpty) {
      _set(AuthStatus.signedOut);
      return;
    }
    try {
      _user = await Services.auth.profile();
      _set(AuthStatus.signedIn);
    } on ApiException {
      await Services.auth.logout();
      _set(AuthStatus.signedOut);
    }
  }

  Future<bool> login(String phoneNumber, String password) async {
    return _guard(() async {
      final signedIn =
          await Services.auth.login(phoneNumber: phoneNumber, password: password);
      // The login payload omits club membership, which the member dashboard
      // needs, so follow up with the full profile. A failure here is not fatal.
      _user = await _profileOr(signedIn);
      _set(AuthStatus.signedIn);
    });
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    String? email,
    String countryCode = '+91',
    required String phoneNumber,
    required String password,
    String? referralCode,
  }) async {
    return _guard(() async {
      final created = await Services.auth.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        password: password,
        referralCode: referralCode,
      );
      _user = await _profileOr(created);
      _set(AuthStatus.signedIn);
    });
  }

  /// Re-reads the profile, e.g. after a bet changes the credit balance.
  Future<void> refresh() async {
    if (_status != AuthStatus.signedIn) return;
    try {
      _user = await Services.auth.profile();
      notifyListeners();
    } on ApiException {
      // Keep showing the last known profile rather than bouncing the user out.
    }
  }

  Future<void> logout() async {
    await Services.auth.logout();
    _user = null;
    _error = null;
    _set(AuthStatus.signedOut);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<AppUser> _profileOr(AppUser fallback) async {
    try {
      return await Services.auth.profile();
    } on ApiException {
      return fallback;
    }
  }

  /// Runs [action], surfacing any [ApiException] as [error] instead of throwing.
  Future<bool> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
