import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_fe/services/auth_api.dart';
import 'package:stellar_fe/services/jobs_api.dart';

Map<String, dynamic> jobJson({String id = 'job-1'}) => {
  'id': id,
  'title': 'Junior developer',
  'company': 'Synthetic Studio',
  'organization_id': 'org-1',
  'description': 'Build useful software.',
  'location': 'Bandung',
  'industry': 'Technology',
  'employment_type': 'full-time',
  'work_mode': 'hybrid',
  'currency': 'IDR',
  'status': 'active',
  'requirements': ['SQL'],
  'highlights': ['Learn with a team'],
  'salary_min': 5000000,
  'salary_max': 8000000,
  'synthetic': true,
  'can_manage': true,
};

void main() {
  test(
    'listing sends encoded filters and bearer auth, parses pagination',
    () async {
      late http.Request captured;
      final api = JobsApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'data': [jobJson()],
              'organizations': [
                {
                  'id': 'org-1',
                  'name': 'Studio',
                  'can_post': true,
                  'can_manage': true,
                },
              ],
              'meta': {'page': 2, 'total': 13, 'total_pages': 2},
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final result = await api.list(
        'access-token',
        filters: {'q': 'R&D / SQL', 'work_mode': 'remote'},
        page: 2,
      );
      expect(captured.headers['authorization'], 'Bearer access-token');
      expect(captured.url.path, '/api/jobs');
      expect(captured.url.queryParameters['q'], 'R&D / SQL');
      expect(captured.url.queryParameters['page'], '2');
      expect(result.totalPages, 2);
      expect(result.jobs.single.synthetic, isTrue);
      expect(result.jobs.single.salaryLabel, 'IDR 5,000,000–8,000,000 / month');
      expect(result.organizations.single.canPost, isTrue);
    },
  );

  test('save and delete use real REST methods and bodies', () async {
    final requests = <http.Request>[];
    final api = JobsApi(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') return http.Response('', 204);
        return http.Response(
          jsonEncode({'data': jobJson()}),
          request.method == 'POST' ? 201 : 200,
        );
      }),
    );
    addTearDown(api.close);
    await api.save('token', {'title': 'New role', 'organization_id': 'org-1'});
    await api.save('token', {'title': 'Updated'}, id: 'job-1');
    await api.get('token', 'job-1');
    await api.delete('token', 'job-1');
    expect(requests.map((r) => r.method), ['POST', 'PATCH', 'GET', 'DELETE']);
    expect(jsonDecode(requests.first.body)['organization_id'], 'org-1');
    expect(requests[1].url.path, '/api/jobs/job-1');
  });

  test(
    '401 is passed to Session refresh; validation fields stay actionable',
    () async {
      final unauthorized = JobsApi(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      addTearDown(unauthorized.close);
      await expectLater(
        unauthorized.get('old', 'id'),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      final invalid = JobsApi(
        baseUrl: 'http://test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'validation_failed',
              'fields': {
                'title': ['is required'],
              },
            }),
            422,
          ),
        ),
      );
      addTearDown(invalid.close);
      await expectLater(
        invalid.save('token', {}),
        throwsA(
          isA<JobsApiException>().having((e) => e.fields['title'], 'field', [
            'is required',
          ]),
        ),
      );
    },
  );

  test(
    'missing salaries and malformed server responses are handled honestly',
    () async {
      final json = jobJson()
        ..['salary_min'] = null
        ..['salary_max'] = null;
      expect(JobListing.fromJson(json).salaryLabel, 'Salary not disclosed');
      final api = JobsApi(
        baseUrl: 'http://test',
        client: MockClient(
          (_) async => http.Response('<html>bad gateway</html>', 502),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.get('token', 'id'),
        throwsA(isA<JobsApiException>()),
      );
    },
  );
}
