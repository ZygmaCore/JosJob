import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/services/auth_api.dart';
import 'package:josjob_fe/services/jobs_overview_api.dart';
import 'jobs_api_test.dart' show jobJson;

Map<String, dynamic> jobsOverviewJson({
  bool empty = false,
  int total = 12,
  int progress = 65,
}) => {
  'stats': {
    'available_jobs': empty ? 0 : total,
    'remote_jobs': empty ? 0 : 3,
    'full_time_jobs': empty ? 0 : 8,
    'published_last_7_days': empty ? 0 : 4,
  },
  'jobs': empty ? [] : [jobJson()],
  'organizations': empty
      ? []
      : [
          {
            'id': 'org-1',
            'name': 'Synthetic Studio',
            'can_post': false,
            'can_manage': false,
          },
        ],
  'profile': {
    'onboarding_progress': progress,
    'mandatory_completed': true,
    'skills': empty ? [] : ['SQL', 'Elixir'],
    'skill_count': empty ? 0 : 2,
    'experience_count': empty ? 0 : 1,
    'education_count': empty ? 0 : 1,
    'certificates_saved': empty ? 0 : 3,
  },
  'capabilities': {
    'matching': false,
    'applications': false,
    'interviews': false,
  },
};
void main() {
  test(
    'uses the authenticated summary and preserves totals larger than the preview',
    () async {
      final api = JobsOverviewApi(
        baseUrl: 'https://api.example.com/',
        client: MockClient((r) async {
          expect(r.url.path, '/api/me/jobs-overview');
          expect(r.headers['authorization'], 'Bearer token');
          return http.Response(
            jsonEncode({'data': jobsOverviewJson()}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      final data = await api.fetch('token');
      expect(data.availableJobs, 12);
      expect(data.jobs.length, 1);
      expect(data.profile.skills, ['SQL', 'Elixir']);
      expect(data.profile.certificatesSaved, 3);
      expect(data.matchingAvailable, false);
      expect(data.applicationsAvailable, false);
    },
  );
  test(
    'surfaces authentication, server, connection and malformed-response failures',
    () async {
      for (final status in [401, 500]) {
        final api = JobsOverviewApi(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(
          api.fetch('token'),
          status == 401
              ? throwsA(isA<AuthException>())
              : throwsA(isA<JobsOverviewException>()),
        );
        api.close();
      }
      for (final body in [
        '<html>error</html>',
        '{"data":{}}',
        '{"data":null}',
      ]) {
        final api = JobsOverviewApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          api.fetch('token'),
          throwsA(isA<JobsOverviewException>()),
        );
        api.close();
      }
      final api = JobsOverviewApi(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetch('token'),
        throwsA(isA<JobsOverviewException>()),
      );
    },
  );
}
