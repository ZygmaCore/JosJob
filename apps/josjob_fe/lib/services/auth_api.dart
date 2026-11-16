import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

// =========================================================================
// JosJob — Auth API client
//
// Thin JSON + JWT Bearer client for the auth endpoints described in
// docs/api/auth.md:
//   POST /api/auth/register  {full_name, email, password, ...} -> 201 {user, token, refresh_token}
//   POST /api/auth/login     {email, password}                 -> 200 {user, token, refresh_token}
//   POST /api/auth/google    {id_token}                        -> 200 {user, token, refresh_token}
//   POST /api/auth/refresh   {refresh_token}                   -> 200 {user, token, refresh_token}
//
// Backend error bodies are Indonesian; we translate to UI-ready English here so
// the rest of the (English) app never sees raw server strings.
// =========================================================================

/// Returns a trimmed string, or null if the value is missing/blank.
String? _nonEmpty(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

/// The account registration type. Corporation/Institution ("organization")
/// accounts must register with a work email; personal accounts may use any
/// email. `null` means "not yet chosen" (e.g. a fresh Google sign-in picks it
/// during onboarding).
enum AccountType {
  personal,
  organization;

  /// The value sent to / received from the backend (`account_type`).
  String get wire => name; // 'personal' | 'organization'

  static AccountType? fromWire(dynamic v) => switch ((v ?? '').toString()) {
    'personal' => AccountType.personal,
    'organization' => AccountType.organization,
    _ => null,
  };
}

/// The authenticated user, as returned by the backend.
class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;

  /// The chosen registration type, or `null` if not yet chosen (e.g. a fresh
  /// Google sign-in that picks it during onboarding).
  final AccountType? accountType;

  /// Whether the user has finished the mandatory onboarding step. Drives the
  /// onboarding-vs-dashboard routing on every login / Google / reload.
  final bool mandatoryCompleted;

  /// Overall onboarding progress 0..100 (mandatory + optional steps).
  final int onboardingProgress;
  final bool isSuperuser;

  /// System role keys the user holds across their active memberships (e.g.
  /// `["teacher"]`). Drives role-adaptive dashboard/menu selection on the client.
  final List<String> roles;

  /// Whether an organization account has been provisioned (approved) and may
  /// enter the dashboard. Always true for personal accounts.
  final bool approved;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.accountType,
    this.mandatoryCompleted = false,
    this.onboardingProgress = 0,
    required this.isSuperuser,
    this.roles = const [],
    this.approved = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: (j['id'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    fullName: (j['full_name'] ?? '').toString().trim(),
    avatarUrl: _nonEmpty(j['avatar_url']),
    accountType: AccountType.fromWire(j['account_type']),
    mandatoryCompleted: j['mandatory_completed'] == true,
    onboardingProgress: (j['onboarding_progress'] as num?)?.toInt() ?? 0,
    isSuperuser: j['is_superuser'] == true,
    roles: (j['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    approved: j['approved'] == true,
  );

  AuthUser copyWith({
    bool? mandatoryCompleted,
    int? onboardingProgress,
    AccountType? accountType,
  }) => AuthUser(
    id: id,
    email: email,
    fullName: fullName,
    avatarUrl: avatarUrl,
    accountType: accountType ?? this.accountType,
    mandatoryCompleted: mandatoryCompleted ?? this.mandatoryCompleted,
    onboardingProgress: onboardingProgress ?? this.onboardingProgress,
    isSuperuser: isSuperuser,
    roles: roles,
    approved: approved,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'account_type': accountType?.wire,
    'mandatory_completed': mandatoryCompleted,
    'onboarding_progress': onboardingProgress,
    'is_superuser': isSuperuser,
    'roles': roles,
    'approved': approved,
  };

  /// True when the user holds the `teacher` system role.
  bool get isTeacher => roles.contains('teacher');

  /// Best-effort first name for greetings ("Welcome back, Budi").
  String get firstName => fullName.trim().isEmpty
      ? ''
      : fullName.trim().split(RegExp(r'\s+')).first;
}

/// A successful auth result: the user plus the access + refresh tokens.
class AuthSession {
  final AuthUser user;
  final String token;
  final String refreshToken;

  /// True when the backend just created this account (Google sign-in of a new
  /// user) — the client routes first-timers into onboarding.
  final bool isNewUser;

  const AuthSession({
    required this.user,
    required this.token,
    required this.refreshToken,
    this.isNewUser = false,
  });

  factory AuthSession.fromJson(Map<String, dynamic> j) {
    final rawUser = j['user'];
    return AuthSession(
      user: AuthUser.fromJson(
        rawUser is Map
            ? rawUser.map((k, v) => MapEntry(k.toString(), v))
            : const <String, dynamic>{},
      ),
      token: (j['token'] ?? '').toString(),
      refreshToken: (j['refresh_token'] ?? '').toString(),
      isNewUser: j['is_new_user'] == true,
    );
  }
}

/// A failed auth call, carrying a UI-ready [message] and any per-field errors
/// (keyed by `'email'` / `'password'` / `'full_name'`).
class AuthException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  const AuthException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  @override
  String toString() => 'AuthException($statusCode): $message';
}

const String _kGenericError = 'Something went wrong. Please try again.';
const String _kNetworkError =
    "Can't reach the server. Check your connection and try again.";
const String _kTimeoutError =
    'The server took too long to respond. Please try again.';

/// Internal marker for a non-2xx HTTP response (decoded body attached).
class _ApiError implements Exception {
  final int status;
  final Map<String, dynamic> body;
  const _ApiError(this.status, this.body);
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  // ---- register --------------------------------------------------------
  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required AccountType accountType,
    String? phone,
    String? address,
    String? birthdate,
  }) async {
    try {
      final body = await _post('/api/auth/register', {
        'full_name': fullName,
        'email': email,
        'password': password,
        'account_type': accountType.wire,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
        if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
      });
      return _requireSession(body);
    } on _ApiError catch (e) {
      if (e.status == 422) {
        final fields = _parseFieldErrors(e.body);
        throw AuthException(
          fields.isNotEmpty
              ? 'Please fix the highlighted fields.'
              : 'We could not create your account. Please try again.',
          statusCode: 422,
          fieldErrors: fields,
        );
      }
      if (e.status == 400) {
        throw const AuthException(
          'Please enter your name, email and a password of at least 8 characters.',
          statusCode: 400,
        );
      }
      throw AuthException(_kGenericError, statusCode: e.status);
    }
  }

  // ---- login -----------------------------------------------------------
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final body = await _post('/api/auth/login', {
        'email': email,
        'password': password,
      });
      return _requireSession(body);
    } on _ApiError catch (e) {
      if (e.status == 401) {
        throw const AuthException(
          'Incorrect email or password.',
          statusCode: 401,
        );
      }
      if (e.status == 400) {
        throw const AuthException(
          'Please enter your email and password.',
          statusCode: 400,
        );
      }
      throw AuthException(_kGenericError, statusCode: e.status);
    }
  }

  // ---- google ----------------------------------------------------------
  Future<AuthSession> google(String idToken) async {
    try {
      final body = await _post('/api/auth/google', {'id_token': idToken});
      return _requireSession(body);
    } on _ApiError catch (e) {
      if (e.status == 401) {
        throw const AuthException(
          'Google sign-in was rejected. Please try again.',
          statusCode: 401,
        );
      }
      if (e.status == 400) {
        throw const AuthException(
          'Google sign-in failed (missing token).',
          statusCode: 400,
        );
      }
      throw AuthException(_kGenericError, statusCode: e.status);
    }
  }

  // ---- refresh ---------------------------------------------------------
  Future<AuthSession> refresh(String refreshToken) async {
    try {
      final body = await _post('/api/auth/refresh', {
        'refresh_token': refreshToken,
      });
      return _requireSession(body);
    } on _ApiError catch (e) {
      throw AuthException('Your session has expired.', statusCode: e.status);
    }
  }

  // ---- onboarding (authenticated) --------------------------------------
  /// Updates onboarding [progress] (0..100) and/or marks the mandatory step
  /// complete for the bearer of [accessToken]. Returns the updated user.
  Future<AuthUser> updateOnboarding(
    String accessToken, {
    int? progress,
    bool? mandatoryCompleted,
  }) async {
    try {
      final body = await _post('/api/onboarding/progress', {
        'progress': ?progress,
        'mandatory_completed': ?mandatoryCompleted,
      }, token: accessToken);
      final raw = body['user'];
      return AuthUser.fromJson(
        raw is Map
            ? raw.map((k, v) => MapEntry(k.toString(), v))
            : const <String, dynamic>{},
      );
    } on _ApiError catch (e) {
      throw AuthException(_kGenericError, statusCode: e.status);
    }
  }

  // ---- account type (authenticated) ------------------------------------
  /// Sets the [type] for the bearer of [accessToken] (the Google/onboarding
  /// path — email+password sign-up sets it at registration). Throws an
  /// [AuthException] with an `'email'` field error if a work email is required
  /// (organization) but the account uses a free provider. Returns the updated
  /// user on success.
  Future<AuthUser> setAccountType(String accessToken, AccountType type) async {
    try {
      final body = await _post('/api/onboarding/account-type', {
        'account_type': type.wire,
      }, token: accessToken);
      final raw = body['user'];
      return AuthUser.fromJson(
        raw is Map
            ? raw.map((k, v) => MapEntry(k.toString(), v))
            : const <String, dynamic>{},
      );
    } on _ApiError catch (e) {
      if (e.status == 422) {
        final fields = _parseFieldErrors(e.body);
        throw AuthException(
          fields['email'] ??
              'Corporation or institution accounts must use a work email.',
          statusCode: 422,
          fieldErrors: fields,
        );
      }
      throw AuthException(_kGenericError, statusCode: e.status);
    }
  }

  // ---- onboarding answers (authenticated) ------------------------------
  /// Replaces the signed-in user's onboarding answers document. [updatedAt] is
  /// a client ISO-8601 timestamp the backend uses for last-write-wins, so
  /// replaying a stale queued write is a no-op. Idempotent full-document PUT.
  Future<void> putAnswers(
    String accessToken, {
    required Map<String, dynamic> answers,
    required String updatedAt,
  }) async {
    try {
      await _send('PUT', '/api/onboarding/answers', {
        'answers': answers,
        'updated_at': updatedAt,
      }, token: accessToken);
    } on _ApiError catch (e) {
      throw AuthException(_kGenericError, statusCode: e.status);
    }
  }

  void close() => _client.close();

  // ---- internals -------------------------------------------------------
  // A 2xx response with a missing/empty token (e.g. an empty body, a 204, or an
  // HTML/error page served with status 200 by a proxy) is not a valid session.
  // Surface it as an AuthException so it flows through the callers' handlers
  // instead of throwing an uncaught cast error.
  AuthSession _requireSession(Map<String, dynamic> body) {
    final session = AuthSession.fromJson(body);
    if (session.token.isEmpty) throw const AuthException(_kGenericError);
    return session;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) => _send('POST', path, body, token: token);

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = jsonEncode(body);
    final http.Response res;
    try {
      final request = method == 'PUT'
          ? _client.put(uri, headers: headers, body: encoded)
          : _client.post(uri, headers: headers, body: encoded);
      res = await request.timeout(_timeout);
    } on TimeoutException {
      throw const AuthException(_kTimeoutError);
    } on AuthException {
      rethrow;
    } catch (_) {
      // SocketException / http.ClientException / CORS failure on web, etc.
      throw const AuthException(_kNetworkError);
    }

    final decoded = _tryDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded ?? const {};
    }
    throw _ApiError(res.statusCode, decoded ?? const {});
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Maps the backend's 422 `details` list to friendly per-field messages.
  Map<String, String> _parseFieldErrors(Map<String, dynamic> body) {
    final details = body['details'];
    if (details is! List) return const {};
    final out = <String, String>{};
    for (final d in details) {
      if (d is! Map) continue;
      final rawField = d['field'];
      final field = rawField is List
          ? (rawField.isEmpty ? null : rawField.first.toString())
          : rawField?.toString();
      if (field == null) continue;
      final msg = (d['message'] ?? '').toString().toLowerCase();
      out[field] = _friendlyFieldMessage(field, msg);
    }
    return out;
  }

  String _friendlyFieldMessage(String field, String rawMessage) {
    if (field == 'email') {
      if (rawMessage.contains('work email') ||
          rawMessage.contains('free email')) {
        return 'Corporation or institution accounts must use a work email '
            '(not a free provider like gmail.com).';
      }
      if (rawMessage.contains('taken') || rawMessage.contains('unique')) {
        return 'That email is already registered.';
      }
      return 'Please enter a valid email address.';
    }
    if (field == 'password') {
      return 'Password must be at least 8 characters.';
    }
    if (field == 'full_name') {
      return 'Please enter your full name.';
    }
    return 'Please check this field.';
  }
}
