import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart' show AuthException;

class LearningOverviewException implements Exception {
  final String message;
  final int? statusCode;
  const LearningOverviewException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class LearningCourse {
  final String id, title, description, currency;
  final String? section;
  final int? priceCents;
  const LearningCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.currency,
    this.section,
    this.priceCents,
  });
  factory LearningCourse.fromJson(Map<String, dynamic> j) => LearningCourse(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    currency: j['currency'] as String,
    section: j['section'] as String?,
    priceCents: (j['price_cents'] as num?)?.toInt(),
  );
}

class LearningEnrollment {
  final String id, classId, classTitle;
  final LearningCourse course;
  const LearningEnrollment({
    required this.id,
    required this.classId,
    required this.classTitle,
    required this.course,
  });
  factory LearningEnrollment.fromJson(Map<String, dynamic> j) =>
      LearningEnrollment(
        id: j['id'] as String,
        classId: j['class_id'] as String,
        classTitle: j['class_title'] as String? ?? '',
        course: LearningCourse.fromJson(j['course'] as Map<String, dynamic>),
      );
}

class LearningSession {
  final String classId, courseId, courseTitle, date;
  final String? instructor, start, end;
  const LearningSession({
    required this.classId,
    required this.courseId,
    required this.courseTitle,
    required this.date,
    this.instructor,
    this.start,
    this.end,
  });
  factory LearningSession.fromJson(Map<String, dynamic> j) => LearningSession(
    classId: j['class_id'] as String,
    courseId: j['course_id'] as String,
    courseTitle: j['course_title'] as String,
    date: j['date'] as String,
    instructor: j['instructor'] as String?,
    start: j['start'] as String?,
    end: j['end'] as String?,
  );
  String get scheduleLabel => [
    date,
    if (start != null && start!.isNotEmpty)
      '$start${end == null || end!.isEmpty ? '' : '–$end'}',
  ].join(' · ');
}

class LearningCompletion {
  final String id, title;
  final int enrolled, completed;
  const LearningCompletion({
    required this.id,
    required this.title,
    required this.enrolled,
    required this.completed,
  });
  factory LearningCompletion.fromJson(
    Map<String, dynamic> j, {
    bool member = false,
  }) => LearningCompletion(
    id: j[member ? 'id' : 'course_id'] as String,
    title: j[member ? 'name' : 'title'] as String? ?? 'Unnamed learner',
    enrolled: (j['enrollment_count'] as num).toInt(),
    completed: (j['completed_count'] as num).toInt(),
  );
  double get fraction => enrolled == 0 ? 0 : (completed / enrolled).clamp(0, 1);
}

class LearningOverview {
  final String scope;
  final Map<String, int> stats;
  final List<LearningEnrollment> enrollments;
  final List<LearningCourse> courses;
  final List<LearningSession> sessions;
  final List<LearningCompletion> members, completion;
  const LearningOverview({
    required this.scope,
    required this.stats,
    required this.enrollments,
    required this.courses,
    required this.sessions,
    required this.members,
    required this.completion,
  });
  factory LearningOverview.fromJson(Map<String, dynamic> j) => LearningOverview(
    scope: j['scope'] as String,
    stats: (j['stats'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    ),
    enrollments: (j['enrollments'] as List)
        .map((v) => LearningEnrollment.fromJson(v as Map<String, dynamic>))
        .toList(),
    courses: (j['courses'] as List)
        .map((v) => LearningCourse.fromJson(v as Map<String, dynamic>))
        .toList(),
    sessions: (j['upcoming_sessions'] as List)
        .map((v) => LearningSession.fromJson(v as Map<String, dynamic>))
        .toList(),
    members: (j['members'] as List)
        .map(
          (v) => LearningCompletion.fromJson(
            v as Map<String, dynamic>,
            member: true,
          ),
        )
        .toList(),
    completion: (j['completion'] as List)
        .map((v) => LearningCompletion.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}

class LearningOverviewApi {
  final http.Client _client;
  final String _baseUrl;
  LearningOverviewApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<LearningOverview> fetch(
    String token, {
    bool organization = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/me/learning-overview').replace(
      queryParameters: {'scope': organization ? 'organization' : 'learner'},
    );
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              'authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        throw const AuthException('Please sign in again.', statusCode: 401);
      }
      if (response.statusCode != 200) {
        throw LearningOverviewException(
          response.statusCode == 403
              ? 'You need permission to view members, courses and enrollments in this organization.'
              : 'Your learning overview could not be loaded. Please try again.',
          statusCode: response.statusCode,
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final overview = LearningOverview.fromJson(
        body['data'] as Map<String, dynamic>,
      );
      final scope = organization ? 'organization' : 'learner';
      final requiredStats = [
        'active_enrollments',
        'completed_enrollments',
        'available_courses',
        'upcoming_sessions',
        if (organization) 'members',
      ];
      if (overview.scope != scope ||
          requiredStats.any((key) => !overview.stats.containsKey(key))) {
        throw const FormatException('Incomplete learning summary');
      }
      return overview;
    } on AuthException {
      rethrow;
    } on LearningOverviewException {
      rethrow;
    } on TimeoutException {
      throw const LearningOverviewException(
        'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const LearningOverviewException(
        'Check your connection and try again.',
      );
    } on FormatException {
      throw const LearningOverviewException(
        'The server returned an unreadable overview. Please try again.',
      );
    } on TypeError {
      throw const LearningOverviewException(
        'The server returned an incomplete overview. Please try again.',
      );
    }
  }

  void close() => _client.close();
}
