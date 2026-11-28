import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_api.dart';

// =========================================================================
// JosJob — Token storage
//
// Persists the access token, refresh token and cached user profile in
// flutter_secure_storage (per docs/api/auth.md). On web this is an
// encrypted-in-localStorage backend; on native it uses the OS keystore.
// =========================================================================
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _kToken = 'josjob.access_token';
  static const String _kRefresh = 'josjob.refresh_token';
  static const String _kUser = 'josjob.user';

  Future<void> save(AuthSession session) async {
    await _storage.write(key: _kToken, value: session.token);
    await _storage.write(key: _kRefresh, value: session.refreshToken);
    await _storage.write(key: _kUser, value: jsonEncode(session.user.toJson()));
  }

  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<AuthUser?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AuthUser.fromJson(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {
      /* corrupt cache — treat as no user */
    }
    return null;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}
