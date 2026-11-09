import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart' show AuthException, AuthSession, AuthUser;

// =========================================================================
// ATVETI STELLAR — Teacher invitations API client
//
// Two surfaces of StellarWeb's invitation endpoints:
//
//  ADMIN (superuser, Bearer access token):
//    GET  /api/admin/teacher-invitations             -> { data: [ {…invitation} ] }
//    POST /api/admin/teacher-invitations             -> { data: {…invitation} }
//    POST /api/admin/teacher-invitations/:id/resend  -> { data: {…invitation} }
//    GET  /api/admin/organizations                   -> { data: [ {id,name} ] }
//
//  PUBLIC (token-gated, NO login) — the invite-accept deep link:
//    GET  /api/invitations/:token          -> { data: {email, organization_name, …} }
//    POST /api/invitations/:token/accept   -> { user, token, refresh_token, is_new_user }
//
// Admin 401s throw the shared [AuthException] so Session.runAuthed rotates the
// refresh token and retries; other failures throw [InvitationApiException].
// =========================================================================

String? _nonEmpty(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _parseDate(dynamic v) {
  final s = _nonEmpty(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// One teacher invitation, as shown in the superuser admin list.
class TeacherInvitation {
  final String id;
  final String email;
  final String organizationId;
  final String? organizationName;
  final String roleKey;

  /// `pending` | `accepted` | `revoked`.
  final String status;
  final int resendCount;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? lastSentAt;

  const TeacherInvitation({
    required this.id,
    required this.email,
    required this.organizationId,
    required this.roleKey,
    required this.status,
    this.organizationName,
    this.resendCount = 0,
    this.expiresAt,
    this.acceptedAt,
    this.lastSentAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  factory TeacherInvitation.fromJson(Map<String, dynamic> j) =>
      TeacherInvitation(
        id: (j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        organizationId: (j['organization_id'] ?? '').toString(),
        organizationName: _nonEmpty(j['organization_name']),
        roleKey: (j['role_key'] ?? 'teacher').toString(),
        status: (j['status'] ?? 'pending').toString(),
        resendCount: (j['resend_count'] as num?)?.toInt() ?? 0,
        expiresAt: _parseDate(j['expires_at']),
        acceptedAt: _parseDate(j['accepted_at']),
        lastSentAt: _parseDate(j['last_sent_at']),
      );
}

/// An organization option for the invite form's dropdown.
class OrgOption {
  final String id;
  final String name;
  const OrgOption({required this.id, required this.name});

  factory OrgOption.fromJson(Map<String, dynamic> j) => OrgOption(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}

/// Public info about an invitation (for the accept screen's prefill).
class InvitationInfo {
  final String email;
  final String? organizationName;
  final String roleKey;
  final String status;

  const InvitationInfo({
    required this.email,
    required this.roleKey,
    required this.status,
    this.organizationName,
  });

  factory InvitationInfo.fromJson(Map<String, dynamic> j) => InvitationInfo(
    email: (j['email'] ?? '').toString(),
    organizationName: _nonEmpty(j['organization_name']),
    roleKey: (j['role_key'] ?? 'teacher').toString(),
    status: (j['status'] ?? 'pending').toString(),
  );
}

/// Result of accepting an invitation. A brand-new account carries a [session]
/// (auto-login); an email that already had an account has [isNewUser] false and
/// a null session (the client sends them to the normal login screen).
class InvitationAcceptResult {
  final AuthUser user;
  final AuthSession? session;
  final bool isNewUser;

  const InvitationAcceptResult({
    required this.user,
    required this.isNewUser,
    this.session,
  });
}

/// A failed invitation API call carrying a UI-ready [message].
class InvitationApiException implements Exception {
  final String message;
  final int? statusCode;
  const InvitationApiException(this.message, {this.statusCode});

  @override
  String toString() => 'InvitationApiException($statusCode): $message';
}

const String _kGenericError = 'Something went wrong. Please try again.';
const String _kNetworkError =
    "Can't reach the server. Check your connection and try again.";
const String _kTimeoutError =
    'The server took too long to respond. Please try again.';

class InvitationsApi {
  InvitationsApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  // ---- admin (superuser) ----------------------------------------------

  Future<List<TeacherInvitation>> list(String accessToken) async {
    final body = await _send(
      'GET',
      '/api/admin/teacher-invitations',
      token: accessToken,
    );
    return _list(body).map(TeacherInvitation.fromJson).toList();
  }

  Future<TeacherInvitation> create(
    String accessToken, {
    required String email,
    required String organizationId,
  }) async {
    final body = await _send(
      'POST',
      '/api/admin/teacher-invitations',
      token: accessToken,
      body: {'email': email, 'organization_id': organizationId},
    );
    return TeacherInvitation.fromJson(_requireData(body));
  }

  Future<TeacherInvitation> resend(String accessToken, String id) async {
    final body = await _send(
      'POST',
      '/api/admin/teacher-invitations/$id/resend',
      token: accessToken,
      body: const {},
    );
    return TeacherInvitation.fromJson(_requireData(body));
  }

  Future<List<OrgOption>> listOrganizations(String accessToken) async {
    final body = await _send(
      'GET',
      '/api/admin/organizations',
      token: accessToken,
    );
    return _list(body).map(OrgOption.fromJson).toList();
  }

  // ---- public (invite accept) -----------------------------------------

  /// Fetches an invitation by its opaque [inviteToken] (no login).
  Future<InvitationInfo> fetch(String inviteToken) async {
    final body = await _send('GET', '/api/invitations/$inviteToken');
    return InvitationInfo.fromJson(_requireData(body));
  }

  /// Accepts [inviteToken], creating (or linking) a teacher account.
  Future<InvitationAcceptResult> accept(
    String inviteToken, {
    required String fullName,
    required String password,
  }) async {
    final body = await _send(
      'POST',
      '/api/invitations/$inviteToken/accept',
      body: {'full_name': fullName, 'password': password},
    );

    final isNew = body['is_new_user'] == true;
    final session = isNew ? AuthSession.fromJson(body) : null;

    final rawUser = body['user'];
    final user = AuthUser.fromJson(
      rawUser is Map
          ? rawUser.map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{},
    );

    return InvitationAcceptResult(
      user: user,
      isNewUser: isNew,
      session: session,
    );
  }

  void close() => _client.close();

  // ---- internals -------------------------------------------------------

  List<Map<String, dynamic>> _list(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    }
    throw const InvitationApiException(_kGenericError);
  }

  Map<String, dynamic> _requireData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return data.cast<String, dynamic>();
    throw const InvitationApiException(_kGenericError);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    final http.Response res;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      final future = switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        _ => _client.get(uri, headers: headers),
      };
      res = await future.timeout(_timeout);
    } on TimeoutException {
      throw const InvitationApiException(_kTimeoutError);
    } catch (_) {
      throw const InvitationApiException(_kNetworkError);
    }

    final decoded = _tryDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded ?? const {};
    }
    // 401 → AuthException so Session.runAuthed refreshes + retries (admin calls).
    if (res.statusCode == 401) {
      throw const AuthException('Your session has expired.', statusCode: 401);
    }
    throw InvitationApiException(
      _errorMessage(res.statusCode, decoded),
      statusCode: res.statusCode,
    );
  }

  String _errorMessage(int status, Map<String, dynamic>? body) {
    switch (body?['error']?.toString()) {
      case 'not_found':
        return 'This invitation link is invalid or no longer exists.';
      case 'expired':
        return 'This invitation has expired. Ask your admin to resend it.';
      case 'already_accepted':
        return 'This invitation has already been used.';
      case 'revoked':
        return 'This invitation has been revoked.';
      case 'invalid_email':
        return 'Please enter a valid email address.';
      case 'email_required':
        return 'Please enter an email address.';
      case 'organization_required':
        return 'Please choose an organization.';
      case 'organization_not_found':
        return 'That organization no longer exists.';
      case 'full_name_required':
        return 'Please enter your full name.';
      case 'password_too_short':
        return 'Password must be at least 8 characters.';
      case 'email_failed':
        return 'The invitation was saved but the email could not be sent.';
      case 'forbidden':
        return 'You do not have permission to do that.';
    }
    if (status == 403) return 'You do not have permission to do that.';
    return _kGenericError;
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
}
