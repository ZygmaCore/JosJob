import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart' show AuthException;

// =========================================================================
// JosJob — Classes + enrollments API client
//
// The two learning-domain reads a live session needs (Bearer access token):
//
//   GET /api/me/classes      -> { data: [ {id, title, course:{id,title}} ] }
//     Classes the caller INSTRUCTS (teacher) — the picker for starting a live
//     session for a class (room `class:<id>`, gated by enrollment server-side).
//
//   GET /api/me/enrollments  -> { data: [ {id, status, class:{id,title,course}} ] }
//     Classes the caller is ENROLLED in (student) — what they may join.
//
// On a 401 the calls throw the shared [AuthException] (statusCode 401) so
// Session.runAuthed rotates the refresh token and retries; other failures
// throw [ClassApiException] with a UI-ready message.
// =========================================================================

/// A class the caller can start (as instructor) or join (as enrolled student).
class LiveClass {
  final String id;
  final String title;
  final String? courseTitle;

  const LiveClass({required this.id, required this.title, this.courseTitle});

  /// From a class object: `{id, title, course: {title}}`.
  factory LiveClass.fromClassJson(Map<String, dynamic> j) => LiveClass(
    id: (j['id'] ?? '').toString(),
    title: _title(j['title']),
    courseTitle: _courseTitle(j['course']),
  );

  /// From an enrollment object: `{class: {…}}`. Null when the class is absent.
  static LiveClass? fromEnrollmentJson(Map<String, dynamic> j) {
    final c = j['class'];
    if (c is Map) return LiveClass.fromClassJson(c.cast<String, dynamic>());
    return null;
  }

  static String _title(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? 'Untitled class' : s;
  }

  static String? _courseTitle(dynamic course) {
    if (course is! Map) return null;
    final t = (course['title'] ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }
}

/// A failed classes/enrollments API call carrying a UI-ready [message].
class ClassApiException implements Exception {
  final String message;
  final int? statusCode;
  const ClassApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ClassApiException($statusCode): $message';
}

const String _kGenericError = 'Something went wrong. Please try again.';
const String _kNetworkError =
    "Can't reach the server. Check your connection and try again.";
const String _kTimeoutError =
    'The server took too long to respond. Please try again.';

class ClassesApi {
  ClassesApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  /// Classes the caller instructs (teacher).
  Future<List<LiveClass>> listMyClasses(String token) async {
    final body = await _get('/api/me/classes', token: token);
    return _list(body).map(LiveClass.fromClassJson).toList();
  }

  /// Classes the caller is enrolled in (student). Enrollments without a class
  /// object are skipped.
  Future<List<LiveClass>> listMyEnrollments(String token) async {
    final body = await _get('/api/me/enrollments', token: token);
    return _list(
      body,
    ).map(LiveClass.fromEnrollmentJson).whereType<LiveClass>().toList();
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
    throw const ClassApiException(_kGenericError);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final http.Response res;
    try {
      res = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ClassApiException(_kTimeoutError);
    } catch (_) {
      throw const ClassApiException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _tryDecode(res.body) ?? const {};
    }
    // 401 → throw AuthException so Session.runAuthed refreshes + retries.
    if (res.statusCode == 401) {
      throw const AuthException('Your session has expired.', statusCode: 401);
    }
    throw ClassApiException(_kGenericError, statusCode: res.statusCode);
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
