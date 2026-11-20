import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/services/auth_api.dart';
import 'package:josjob_fe/services/curriculum_vitae_api.dart';
import 'certificates_api_test.dart' show certificateJson;

Map<String, dynamic> cvJson({
  bool empty = false,
  bool attached = false,
  String? headline = 'Actual headline',
  String? summary = 'Actual professional summary',
}) => {
  'identity': {
    'full_name': 'Actual Candidate',
    'email': 'candidate@example.com',
    'phone': empty ? null : '+62 12345',
    'location': empty ? null : 'Indonesia',
  },
  'headline': empty ? null : headline,
  'summary': empty ? null : summary,
  'skills': empty ? [] : ['SQL', 'Elixir'],
  'experience': empty
      ? []
      : [
          {
            'name': 'Actual employer',
            'position': 'Developer',
            'from': '2021-04',
            'to': null,
            'country': 'Indonesia',
            'internship': false,
          },
        ],
  'education': empty
      ? []
      : [
          {
            'name': 'Actual university',
            'degree': 'Bachelor degree',
            'major': 'Computer science',
            'from': '2017',
            'to': '2021-03',
          },
        ],
  'certificates': empty ? [] : [certificateJson()],
  'pdf_documents': empty
      ? []
      : [
          {
            'id': 'pdf-1',
            'title': 'Actual resume.pdf',
            'url': 'https://example.com/resume.pdf',
          },
        ],
  'resume_document': attached
      ? {
          'id': 'pdf-1',
          'title': 'Actual resume.pdf',
          'url': 'https://example.com/resume.pdf',
        }
      : null,
};
void main() {
  test(
    'uses authenticated CV endpoints and preserves real data and partial date precision',
    () async {
      final requests = <http.Request>[];
      final api = CurriculumVitaeApi(
        baseUrl: 'https://api.example.com/',
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({'data': cvJson(attached: true)}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      final d = await api.fetch('token');
      expect(requests.single.url.path, '/api/me/cv');
      expect(requests.single.headers['authorization'], 'Bearer token');
      expect(d.fullName, 'Actual Candidate');
      expect(d.experience.single.period, 'From 2021-04');
      expect(d.education.single.period, '2017 – 2021-03');
      expect(d.resumeDocument!.id, 'pdf-1');
      expect(d.certificates.single.source, 'self_reported');
      await api.save('token', {
        'headline': 'Updated',
        'resume_document_id': null,
      });
      expect(requests.last.method, 'PATCH');
      expect(jsonDecode(requests.last.body), {
        'headline': 'Updated',
        'resume_document_id': null,
      });
    },
  );
  test(
    'handles authentication, validation, connection and malformed responses',
    () async {
      for (final status in [401, 422, 500]) {
        final api = CurriculumVitaeApi(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(
          api.fetch('token'),
          status == 401
              ? throwsA(isA<AuthException>())
              : throwsA(isA<CvException>()),
        );
        api.close();
      }
      for (final body in [
        '<html>error</html>',
        '{"data":{}}',
        '{"data":null}',
      ]) {
        final api = CurriculumVitaeApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(api.fetch('token'), throwsA(isA<CvException>()));
        api.close();
      }
      final api = CurriculumVitaeApi(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(api.close);
      await expectLater(api.fetch('token'), throwsA(isA<CvException>()));
    },
  );
}
