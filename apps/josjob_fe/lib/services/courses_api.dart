import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart' show AuthException;

// =========================================================================
// JosJob — Course catalog API client
//
// The student-facing catalog: active courses shared to the orgs the caller is
// an active member of. Mirrors JosjobWeb.Api.CatalogController (Bearer access
// token):
//
//   GET /api/catalog/courses      -> { data: [ {id, title, description,
//                                       section:{id,name}, industries:[{id,name}],
//                                       class_count} ] }
//
// On a 401 the calls throw the shared [AuthException] (statusCode 401) so
// Session.runAuthed rotates the refresh token and retries; other failures
// throw [CourseApiException] with a UI-ready message.
// =========================================================================

String? _nonEmpty(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Human price label from a smallest-unit amount, e.g. (4900,'usd') -> "$49.00".
String formatPrice(int cents, String currency) {
  final value = (cents / 100).toStringAsFixed(2);
  final symbol = switch (currency.toLowerCase()) {
    'usd' => r'$',
    'eur' => '€',
    'gbp' => '£',
    _ => '',
  };
  return symbol.isEmpty ? '$value ${currency.toUpperCase()}' : '$symbol$value';
}

/// One catalog course as returned by the summary endpoint. Only the fields the
/// backend actually stores — no level/rating/duration/etc.
class CourseSummary {
  final String id;
  final String title;
  final String description;
  final String? sectionName;
  final List<String> industries; // industry names
  final int classCount;
  final int? priceCents; // null/0 = free
  final String currency;

  const CourseSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.industries,
    required this.classCount,
    required this.currency,
    this.sectionName,
    this.priceCents,
  });

  bool get isFree => priceCents == null || priceCents! <= 0;

  /// e.g. "$49.00", or null when free.
  String? get priceLabel => isFree ? null : formatPrice(priceCents!, currency);

  factory CourseSummary.fromJson(Map<String, dynamic> j) => CourseSummary(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    sectionName: _sectionName(j['section']),
    industries: _industries(j['industries']),
    classCount: _int(j['class_count']),
    priceCents: _asIntOrNull(j['price_cents']),
    currency: (j['currency'] ?? 'usd').toString(),
  );

  static String? _sectionName(dynamic section) {
    if (section is! Map) return null;
    return _nonEmpty(section['name']);
  }

  static List<String> _industries(dynamic industries) {
    if (industries is! List) return const [];
    return industries
        .whereType<Map>()
        .map((m) => (m['name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }
}

/// One class (session offering) of a course — what a student actually enrols in.
class CourseClass {
  final String id;
  final String title; // '' when the class is untitled
  final int? seatsLeft; // null = unlimited
  final String? instructorName;
  final bool enrolled; // is the caller already enrolled?
  final String scheduleLabel; // human-readable first-session summary
  final int sessionCount;

  const CourseClass({
    required this.id,
    required this.title,
    required this.enrolled,
    required this.scheduleLabel,
    required this.sessionCount,
    this.seatsLeft,
    this.instructorName,
  });

  bool get isFull => seatsLeft != null && seatsLeft! <= 0;

  factory CourseClass.fromJson(Map<String, dynamic> j) {
    final raw = j['schedule'];
    final sessions = raw is List
        ? raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
        : const <Map<String, dynamic>>[];
    return CourseClass(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString().trim(),
      seatsLeft: _intOrNull(j['seats_left']),
      instructorName: _instructor(j['instructor']),
      enrolled: j['enrolled'] == true,
      scheduleLabel: _scheduleLabel(sessions),
      sessionCount: sessions.length,
    );
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _instructor(dynamic v) {
    if (v is! Map) return null;
    return _nonEmpty(v['full_name']);
  }

  static String _scheduleLabel(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 'Flexible schedule';
    final first = sessions.first;
    final date = _fmtDate(first['date']?.toString());
    final start = (first['start'] ?? '').toString();
    final end = (first['end'] ?? '').toString();
    final time = start.isNotEmpty && end.isNotEmpty
        ? ' · $start–$end'
        : (start.isNotEmpty ? ' · $start' : '');
    final more = sessions.length > 1 ? ' · +${sessions.length - 1} more' : '';
    return '${date ?? 'Scheduled'}$time$more';
  }

  static String? _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]}';
  }
}

/// A course with its classes — the detail behind a catalog entry.
class CourseDetail {
  final String id;
  final String title;
  final String description;
  final String? sectionName;
  final List<String> industries;
  final List<CourseClass> classes;
  final int? priceCents;
  final String currency;

  const CourseDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.industries,
    required this.classes,
    required this.currency,
    this.sectionName,
    this.priceCents,
  });

  bool get isFree => priceCents == null || priceCents! <= 0;
  String? get priceLabel => isFree ? null : formatPrice(priceCents!, currency);

  factory CourseDetail.fromJson(Map<String, dynamic> j) => CourseDetail(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    sectionName: CourseSummary._sectionName(j['section']),
    industries: CourseSummary._industries(j['industries']),
    classes: _classes(j['classes']),
    priceCents: _asIntOrNull(j['price_cents']),
    currency: (j['currency'] ?? 'usd').toString(),
  );

  static List<CourseClass> _classes(dynamic classes) {
    if (classes is! List) return const [];
    return classes
        .whereType<Map>()
        .map((m) => CourseClass.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

/// Result of starting an enrolment. [free] true = enrolled immediately (no
/// payment); otherwise the Stripe fields drive an in-app card payment.
class EnrollStart {
  final bool free;
  final String? clientSecret;
  final String? paymentIntentId;
  final String? publishableKey;
  final int? amountCents;
  final String? currency;

  const EnrollStart({
    required this.free,
    this.clientSecret,
    this.paymentIntentId,
    this.publishableKey,
    this.amountCents,
    this.currency,
  });

  String? get amountLabel => (amountCents == null || currency == null)
      ? null
      : formatPrice(amountCents!, currency!);

  factory EnrollStart.fromJson(Map<String, dynamic> j) => EnrollStart(
    free: j['free'] == true,
    clientSecret: _nonEmpty(j['client_secret']),
    paymentIntentId: _nonEmpty(j['payment_intent_id']),
    publishableKey: _nonEmpty(j['publishable_key']),
    amountCents: _asIntOrNull(j['amount_cents']),
    currency: _nonEmpty(j['currency']),
  );
}

/// A course the caller is enrolled in (from GET /api/me/enrollments) — for the
/// dashboard "My Courses" tab.
class EnrolledCourse {
  final String enrollmentId;
  final String status; // 'active' | 'completed'
  final String? courseId;
  final String courseTitle;
  final String classTitle; // the session title
  final String scheduleLabel;

  const EnrolledCourse({
    required this.enrollmentId,
    required this.status,
    required this.courseTitle,
    required this.classTitle,
    required this.scheduleLabel,
    this.courseId,
  });

  bool get completed => status == 'completed';

  /// From an enrollment object `{id, status, class:{title, schedule, course:{…}}}`.
  /// Null when the class/course is absent.
  static EnrolledCourse? fromJson(Map<String, dynamic> j) {
    final cls = j['class'];
    if (cls is! Map) return null;
    final c = cls.cast<String, dynamic>();
    final course = c['course'] is Map
        ? (c['course'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final raw = c['schedule'];
    final sessions = raw is List
        ? raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
        : const <Map<String, dynamic>>[];
    return EnrolledCourse(
      enrollmentId: (j['id'] ?? '').toString(),
      status: (j['status'] ?? 'active').toString(),
      courseId: _nonEmpty(course['id']),
      courseTitle: (course['title'] ?? 'Course').toString(),
      classTitle: (c['title'] ?? '').toString(),
      scheduleLabel: CourseClass._scheduleLabel(sessions),
    );
  }
}

/// A failed catalog API call carrying a UI-ready [message].
class CourseApiException implements Exception {
  final String message;
  final int? statusCode;
  const CourseApiException(this.message, {this.statusCode});

  @override
  String toString() => 'CourseApiException($statusCode): $message';
}

const String _kGenericError = 'Something went wrong. Please try again.';
const String _kNetworkError =
    "Can't reach the server. Check your connection and try again.";
const String _kTimeoutError =
    'The server took too long to respond. Please try again.';

class CoursesApi {
  CoursesApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  /// Active courses visible to the caller (public + shared to their org), by title.
  Future<List<CourseSummary>> listCourses(String token) async {
    final body = await _get('/api/catalog/courses', token: token);
    return _list(body).map(CourseSummary.fromJson).toList();
  }

  /// Courses the caller is enrolled in (dashboard "My Courses"). Enrollments
  /// whose class/course is missing are skipped.
  Future<List<EnrolledCourse>> listEnrollments(String token) async {
    final body = await _get('/api/me/enrollments', token: token);
    return _list(
      body,
    ).map(EnrolledCourse.fromJson).whereType<EnrolledCourse>().toList();
  }

  /// A single course with its classes (sessions) — for the preview/enrol screen.
  Future<CourseDetail> getCourse(String token, String id) async {
    final body = await _get('/api/catalog/courses/$id', token: token);
    final data = body['data'];
    if (data is Map) return CourseDetail.fromJson(data.cast<String, dynamic>());
    throw const CourseApiException(_kGenericError);
  }

  /// Enrol the caller into a class. Throws [CourseApiException] with a UI-ready
  /// message (full / already enrolled / unavailable) or [AuthException] on 401.
  Future<void> enroll(String token, String classId) async {
    await _send('POST', '/api/classes/$classId/enroll', token: token);
  }

  /// Leave a class the caller is enrolled in.
  Future<void> unenroll(String token, String classId) async {
    await _send('DELETE', '/api/classes/$classId/enroll', token: token);
  }

  /// Start enrolment. FREE ⇒ [EnrollStart.free] is true (the server already
  /// enrolled the caller); PAID ⇒ returns a Stripe client secret + publishable
  /// key so the client can collect a card and confirm the payment.
  Future<EnrollStart> startEnroll(String token, String classId) async {
    final body = await _send(
      'POST',
      '/api/classes/$classId/enroll/intent',
      token: token,
    );
    return EnrollStart.fromJson(body);
  }

  /// Confirm a paid enrolment once the card payment succeeded. The server
  /// re-verifies the PaymentIntent with Stripe before granting the enrolment.
  Future<void> confirmEnroll(
    String token,
    String classId,
    String paymentIntentId,
  ) async {
    await _send(
      'POST',
      '/api/classes/$classId/enroll/confirm',
      token: token,
      body: {'payment_intent_id': paymentIntentId},
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
    throw const CourseApiException(_kGenericError);
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
      throw const CourseApiException(_kTimeoutError);
    } catch (_) {
      throw const CourseApiException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _tryDecode(res.body) ?? const {};
    }
    // 401 → throw AuthException so Session.runAuthed refreshes + retries.
    if (res.statusCode == 401) {
      throw const AuthException('Your session has expired.', statusCode: 401);
    }
    throw CourseApiException(_kGenericError, statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response res;
    try {
      final future = method == 'POST'
          ? _client.post(uri, headers: headers, body: encoded)
          : _client.delete(uri, headers: headers, body: encoded);
      res = await future.timeout(_timeout);
    } on TimeoutException {
      throw const CourseApiException(_kTimeoutError);
    } catch (_) {
      throw const CourseApiException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _tryDecode(res.body) ?? const {};
    }
    if (res.statusCode == 401) {
      throw const AuthException('Your session has expired.', statusCode: 401);
    }
    throw CourseApiException(
      _enrollError(_tryDecode(res.body)),
      statusCode: res.statusCode,
    );
  }

  // Map the backend's `{error: <code>}` responses to UI-ready English.
  String _enrollError(Map<String, dynamic>? body) {
    switch (body?['error']?.toString()) {
      case 'already_enrolled':
        return "You're already enrolled in this session.";
      case 'full':
        return 'This session is full.';
      case 'not_found':
        return 'This session is no longer available.';
      case 'not_enrolled':
        return "You're not enrolled in this session.";
      case 'payment_required':
        return 'This course requires payment.';
      case 'payment_not_completed':
        return "Your payment wasn't completed. Please try again.";
      case 'payment_mismatch':
        return "That payment doesn't match this enrolment.";
      case 'payment_failed':
        return 'The payment could not be processed. Please try again.';
    }
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
