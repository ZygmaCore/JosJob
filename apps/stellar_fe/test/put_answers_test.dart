import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_fe/services/auth_api.dart';

// Deterministic, non-widget unit test for the onboarding-answers sync contract
// (PUT /api/onboarding/answers). Uses a MockClient so it never touches the
// network or google_fonts (which throws in headless widget tests).
void main() {
  const base = 'http://test.local';

  test(
    'putAnswers issues an authenticated PUT with the answers document',
    () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });
      final api = AuthApi(client: client, baseUrl: base);

      await api.putAnswers(
        'tok-123',
        answers: const {
          'skills': ['welding'],
        },
        updatedAt: '2026-07-18T00:00:00.000Z',
      );

      expect(captured.method, 'PUT');
      expect(captured.url.toString(), '$base/api/onboarding/answers');
      expect(captured.headers['Authorization'], 'Bearer tok-123');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['answers'], {
        'skills': ['welding'],
      });
      expect(body['updated_at'], '2026-07-18T00:00:00.000Z');
    },
  );

  test(
    'putAnswers surfaces a non-2xx as an AuthException with the status',
    () async {
      final client = MockClient(
        (req) async => http.Response(jsonEncode({'error': 'nope'}), 400),
      );
      final api = AuthApi(client: client, baseUrl: base);

      expect(
        () => api.putAnswers(
          'tok',
          answers: const {},
          updatedAt: '2026-07-18T00:00:00.000Z',
        ),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    },
  );
}
