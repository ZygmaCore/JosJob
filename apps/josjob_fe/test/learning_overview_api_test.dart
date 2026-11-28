import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/services/auth_api.dart';
import 'package:josjob_fe/services/learning_overview_api.dart';

Map<String, dynamic> overviewJson({
  bool organization = false,
  int active = 2,
}) => {
  'scope': organization ? 'organization' : 'learner',
  'stats': {
    'members': 5,
    'active_enrollments': active,
    'completed_enrollments': 1,
    'available_courses': 7,
    'upcoming_sessions': 1,
  },
  'enrollments': organization
      ? []
      : [
          {
            'id': 'enrollment-1',
            'class_id': 'class-1',
            'class_title': 'Evening SQL',
            'course': {
              'id': 'sql',
              'title': 'SQL foundations',
              'description': 'Practical SQL',
              'section': 'Technology',
              'currency': 'usd',
              'price_cents': 0,
            },
          },
        ],
  'courses': [
    {
      'id': 'python',
      'title': 'Public Python',
      'description': 'Learn Python',
      'section': 'Technology',
      'currency': 'usd',
      'price_cents': 4900,
    },
  ],
  'upcoming_sessions': [
    {
      'class_id': 'class-1',
      'course_id': 'sql',
      'course_title': 'SQL foundations',
      'instructor': 'Actual teacher',
      'date': '2027-02-03',
      'start': '10:00',
      'end': '11:00',
    },
  ],
  'members': organization
      ? [
          {
            'id': 'member-1',
            'name': 'Actual learner',
            'enrollment_count': 2,
            'completed_count': 1,
          },
        ]
      : [],
  'completion': organization
      ? [
          {
            'course_id': 'sql',
            'title': 'SQL foundations',
            'enrollment_count': 2,
            'completed_count': 1,
          },
        ]
      : [],
};

void main() {
  test(
    'requests authenticated summaries with explicit scope and preserves real totals',
    () async {
      final requests = <http.Request>[];
      final api = LearningOverviewApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'data': overviewJson(organization: requests.length == 2),
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final learner = await api.fetch('access-token');
      final organization = await api.fetch('access-token', organization: true);
      expect(requests.first.url.path, '/api/me/learning-overview');
      expect(requests.first.headers['authorization'], 'Bearer access-token');
      expect(requests.map((r) => r.url.queryParameters['scope']), [
        'learner',
        'organization',
      ]);
      expect(learner.stats['active_enrollments'], 2);
      expect(learner.enrollments.single.course.id, 'sql');
      expect(learner.sessions.single.scheduleLabel, '2027-02-03 · 10:00–11:00');
      expect(organization.members.single.fraction, 0.5);
    },
  );

  test(
    '401 reaches session refresh and forbidden summaries explain missing access',
    () async {
      for (final status in [401, 403, 503]) {
        final api = LearningOverviewApi(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetch('token'),
          throwsA(
            status == 401
                ? isA<AuthException>().having(
                    (e) => e.statusCode,
                    'status',
                    401,
                  )
                : isA<LearningOverviewException>().having(
                    (e) => e.statusCode,
                    'status',
                    status,
                  ),
          ),
        );
      }
    },
  );

  test(
    'malformed and incomplete summaries surface errors instead of invented zeros',
    () async {
      final missingStats = overviewJson()..['stats'] = <String, int>{};
      final wrongScope = overviewJson(organization: true);
      for (final body in [
        '<html>bad gateway</html>',
        '{"data":{}}',
        jsonEncode({'data': missingStats}),
        jsonEncode({'data': wrongScope}),
      ]) {
        final api = LearningOverviewApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetch('token'),
          throwsA(isA<LearningOverviewException>()),
        );
      }
    },
  );
}
