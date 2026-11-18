import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/services/applications_api.dart';
import 'package:josjob_fe/services/chat_api.dart';
import 'package:josjob_fe/services/workflow_client.dart';
import 'package:josjob_fe/services/auth_api.dart' show AuthException;
import 'support/workflow_fixtures.dart';

void main() {
  test(
    'application listing sends scoped pagination, filters and bearer auth',
    () async {
      final api = ApplicationsApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer access');
          expect(request.url.path, '/api/applications');
          expect(request.url.queryParameters, {
            'scope': 'hiring',
            'page': '2',
            'status': 'interview',
            'job_id': 'job-1',
          });
          return http.Response(jsonEncode(applicationList(hiring: true)), 200);
        }),
      );
      addTearDown(api.close);
      final result = await api.list(
        'access',
        scope: 'hiring',
        page: 2,
        status: 'interview',
        jobId: 'job-1',
      );
      expect(result.canHire, isTrue);
      expect(result.counts['applied'], 1);
    },
  );
  test(
    'application submission and stage updates carry consent and the last observed stage',
    () async {
      final writes = <Map<String, dynamic>>[];
      final api = ApplicationsApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'data': applicationJson()}), 200);
        }),
      );
      addTearDown(api.close);
      final application = await api.apply(
        'access',
        'job-1',
        coverLetter: 'Hello',
        consent: true,
      );
      await api.advance(
        'access',
        application,
        'reviewing',
        note: 'We are reviewing your profile.',
      );
      expect(writes.first, {'cover_letter': 'Hello', 'consent': true});
      expect(writes.last['expected_status'], 'applied');
      expect(writes.last['status'], 'reviewing');
    },
  );
  test(
    'chat sends an idempotency key and history uses its before cursor',
    () async {
      final api = ChatApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/chats/coaching/booking-1/messages');
          if (request.method == 'GET') {
            expect(request.url.queryParameters['before'], '100');
            return http.Response(jsonEncode(chatJson()), 200);
          }
          expect(jsonDecode(request.body), {
            'body': 'Hello',
            'client_id': 'retry-key',
          });
          return http.Response(jsonEncode({'data': messageJson()}), 201);
        }),
      );
      addTearDown(api.close);
      await api.history('access', 'coaching', 'booking-1', before: '100');
      await api.send('access', 'coaching', 'booking-1', 'Hello', 'retry-key');
    },
  );
  test(
    '401 is available to Session refresh and conflicts have actionable messages',
    () async {
      final expired = ChatApi(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      addTearDown(expired.close);
      await expectLater(
        expired.history('old', 'application', 'id'),
        throwsA(isA<AuthException>()),
      );
      final conflict = ApplicationsApi(
        baseUrl: 'http://test',
        client: MockClient(
          (_) async => http.Response('{"error":"stale_application"}', 409),
        ),
      );
      addTearDown(conflict.close);
      await expectLater(
        conflict.advance(
          'token',
          JobApplication.fromJson(applicationJson()),
          'reviewing',
        ),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.message,
            'message',
            contains('Refresh'),
          ),
        ),
      );
    },
  );
}
