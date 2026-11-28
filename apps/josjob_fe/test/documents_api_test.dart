import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:josjob_fe/services/auth_api.dart' show AuthException;
import 'package:josjob_fe/services/documents_api.dart';

// Contract test: DocumentsApi maps the backend JSON (see
// JosjobWeb.Api.DocumentController) onto the FE models, builds the right
// requests, and surfaces `{error: <code>}` bodies (401 -> AuthException so
// Session.runAuthed refreshes; else DocApiException).

DocumentsApi _apiReturning(
  Object json, {
  int status = 200,
  List<http.Request>? captured,
}) {
  final client = MockClient((req) async {
    captured?.add(req);
    return http.Response(
      jsonEncode(json),
      status,
      headers: {'content-type': 'application/json'},
    );
  });
  return DocumentsApi(client: client, baseUrl: 'http://test');
}

void main() {
  test('listDocuments parses items + relationship + can_manage', () async {
    final api = _apiReturning({
      'data': [
        {
          'id': 'd1',
          'title': 'Intro.mp4',
          'url': 'https://cdn/x.m3u8',
          'mime_type': 'video/mp4',
          'relationship': 'owner',
          'can_manage': true,
        },
        {
          'id': 'd2',
          'title': 'Handbook.pdf',
          'url': 'https://cdn/h.pdf',
          'mime_type': 'application/pdf',
          'relationship': 'shared',
          'can_manage': false,
        },
      ],
    });

    final docs = await api.listDocuments('tok');

    expect(docs, hasLength(2));
    expect(docs[0].relationship, 'owner');
    expect(docs[0].canManage, isTrue);
    expect(docs[0].isVideo, isTrue);
    expect(docs[1].sharedWithMe, isTrue);
    expect(docs[1].isVideo, isFalse);
  });

  test('listGrants parses allow/active/expiry', () async {
    final api = _apiReturning({
      'data': [
        {
          'id': 'g1',
          'document_id': 'd1',
          'user_id': 'u2',
          'email': 'a@b.com',
          'full_name': 'Ann B',
          'allow': true,
          'active': true,
          'valid_from': null,
          'valid_until': '2099-01-01T23:59:59.000Z',
        },
      ],
    });

    final grants = await api.listGrants('tok', 'd1');

    expect(grants, hasLength(1));
    expect(grants.first.email, 'a@b.com');
    expect(grants.first.allow, isTrue);
    expect(grants.first.active, isTrue);
    expect(grants.first.validUntil, isNotNull);
  });

  test('addGrant POSTs email + expiry to the right path', () async {
    final captured = <http.Request>[];
    final api = _apiReturning({
      'data': {
        'id': 'g9',
        'document_id': 'd1',
        'user_id': 'u3',
        'email': 'c@d.com',
        'allow': true,
        'active': true,
      },
    }, captured: captured);

    final expiry = DateTime.utc(2030, 6, 1, 12, 0, 0);
    final grant = await api.addGrant(
      'tok',
      docId: 'd1',
      email: 'c@d.com',
      validUntil: expiry,
    );

    expect(grant.id, 'g9');
    expect(captured, hasLength(1));
    final req = captured.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/api/documents/d1/grants');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['email'], 'c@d.com');
    expect(body['allow'], true);
    expect(body['valid_until'], '2030-06-01T12:00:00.000Z');
  });

  test('addGrant omits valid_until when no expiry', () async {
    final captured = <http.Request>[];
    final api = _apiReturning({
      'data': {
        'id': 'g1',
        'document_id': 'd1',
        'user_id': 'u',
        'allow': true,
        'active': true,
      },
    }, captured: captured);

    await api.addGrant('tok', docId: 'd1', email: 'c@d.com');

    final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
    expect(body.containsKey('valid_until'), isFalse);
    expect(body.containsKey('valid_from'), isFalse);
  });

  test('deleteGrant issues DELETE on the grant path', () async {
    final captured = <http.Request>[];
    final api = _apiReturning({
      'data': {'deleted': true},
    }, captured: captured);

    await api.deleteGrant('tok', docId: 'd1', grantId: 'g9');

    expect(captured.single.method, 'DELETE');
    expect(captured.single.url.path, '/api/documents/d1/grants/g9');
  });

  test('user_not_found surfaces a UI-ready DocApiException', () async {
    final api = _apiReturning({'error': 'user_not_found'}, status: 422);

    expect(
      () => api.addGrant('tok', docId: 'd1', email: 'ghost@x.com'),
      throwsA(
        isA<DocApiException>().having(
          (e) => e.message,
          'message',
          contains('No account'),
        ),
      ),
    );
  });

  test('403 forbidden surfaces a DocApiException', () async {
    final api = _apiReturning({'error': 'forbidden'}, status: 403);

    expect(() => api.listGrants('tok', 'd1'), throwsA(isA<DocApiException>()));
  });

  test('401 throws AuthException (so Session refreshes + retries)', () async {
    final api = _apiReturning({'error': 'unauthorized'}, status: 401);

    expect(
      () => api.listDocuments('tok'),
      throwsA(
        isA<AuthException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
  });
}
