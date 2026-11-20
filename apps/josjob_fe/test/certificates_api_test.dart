import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/services/auth_api.dart';
import 'package:josjob_fe/services/certificates_api.dart';

Map<String, dynamic> certificateJson({
  String id = 'cert-1',
  String title = 'Actual certificate',
  String source = 'self_reported',
}) => {
  'id': id,
  'title': title,
  'issuer': 'Actual issuer',
  'source': source,
  'issued_on': source == 'onboarding' ? null : '2025-01-01',
  'expires_on': null,
  'credential_id': source == 'onboarding' ? null : 'ID-123',
  'credential_url': source == 'onboarding'
      ? null
      : 'https://example.com/credential',
  'recorded_period': source == 'onboarding' ? '2024-06 – 2025' : null,
  'editable': source != 'onboarding',
  'expired': false,
};

void main() {
  test(
    'uses authenticated certificate endpoints for list, add, edit and delete',
    () async {
      final requests = <http.Request>[];
      final api = CertificatesApi(
        baseUrl: 'https://api.example.com/',
        client: MockClient((r) async {
          requests.add(r);
          expect(r.headers['authorization'], 'Bearer token');
          return http.Response(
            jsonEncode(
              r.method == 'GET'
                  ? {
                      'data': [
                        certificateJson(),
                        certificateJson(
                          id: 'onboarding-0',
                          source: 'onboarding',
                        ),
                      ],
                    }
                  : {'ok': true},
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      final certificates = await api.fetch('token');
      expect(certificates.map((c) => c.title), [
        'Actual certificate',
        'Actual certificate',
      ]);
      expect(certificates.last.editable, false);
      expect(certificates.last.issuedOn, null);
      expect(certificates.last.recordedPeriod, '2024-06 – 2025');
      await api.save('token', {
        'title': 'New certificate',
        'issuer': 'Training provider',
      });
      await api.save('token', {'title': 'Updated'}, id: 'cert-1');
      await api.delete('token', 'cert-1');
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/me/certificates',
        'POST /api/me/certificates',
        'PATCH /api/me/certificates/cert-1',
        'DELETE /api/me/certificates/cert-1',
      ]);
      expect(jsonDecode(requests[1].body)['title'], 'New certificate');
    },
  );

  test(
    'handles expired sessions, validation, connection and malformed responses',
    () async {
      for (final status in [401, 404, 422, 500]) {
        final api = CertificatesApi(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(
          api.fetch('token'),
          status == 401
              ? throwsA(isA<AuthException>())
              : throwsA(
                  isA<CertificateException>().having(
                    (e) => e.statusCode,
                    'status',
                    status,
                  ),
                ),
        );
        api.close();
      }
      for (final body in [
        '<html>error</html>',
        '{"data":null}',
        '{"data":[{"id":42}]}',
      ]) {
        final api = CertificatesApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          api.fetch('token'),
          throwsA(isA<CertificateException>()),
        );
        api.close();
      }
      final api = CertificatesApi(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetch('token'),
        throwsA(isA<CertificateException>()),
      );
    },
  );
}
