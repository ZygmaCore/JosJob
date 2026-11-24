import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/services/job_rankings_api.dart';
import 'package:josjob_fe/services/auth_api.dart';

void main() {
  test('upload requires consent without sending CV bytes', () async {
    final api = JobRankingsApi(
      client: MockClient((_) async => throw StateError('must not send')),
    );
    addTearDown(api.close);
    await expectLater(
      api.upload('token', Uint8List.fromList([1]), 'cv.pdf', consent: false),
      throwsA(isA<RankingException>()),
    );
  });

  test('upload sends multipart consent and bearer auth', () async {
    final api = JobRankingsApi(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(request.body, contains('name="consent"'));
        expect(request.body, contains('filename="cv.pdf"'));
        return http.Response(
          jsonEncode({
            'data': {'id': 'extraction-1', 'status': 'queued'},
          }),
          202,
        );
      }),
    );
    addTearDown(api.close);
    final data = await api.upload(
      'token',
      Uint8List.fromList('%PDF-1.4'.codeUnits),
      'cv.pdf',
      consent: true,
    );
    expect(data['id'], 'extraction-1');
  });

  test(
    'ranking uses extraction ID and preserves order and explanations',
    () async {
      final api = JobRankingsApi(
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['extraction_id'], 'owned-extraction');
          return http.Response(
            jsonEncode({
              'data': {
                'jobs': [
                  {'job_id': 'best', 'match': 1.0, 'missing_skills': []},
                  {
                    'job_id': 'next',
                    'match': 0.4,
                    'missing_skills': ['SQL'],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final data = await api.rank('token', 'owned-extraction');
      expect(data['jobs'][0]['job_id'], 'best');
      expect(data['jobs'][1]['missing_skills'], ['SQL']);
    },
  );

  test('expired extraction and unreadable CV show actionable errors', () async {
    for (final status in [404, 422, 503]) {
      final api = JobRankingsApi(
        client: MockClient((_) async => http.Response('{}', status)),
      );
      addTearDown(api.close);
      await expectLater(
        api.extraction('token', 'id'),
        throwsA(isA<RankingException>()),
      );
    }
  });

  test('expired authentication is eligible for session refresh', () async {
    final api = JobRankingsApi(
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    addTearDown(api.close);
    await expectLater(
      api.extraction('token', 'id'),
      throwsA(isA<AuthException>()),
    );
  });
}
