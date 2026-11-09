import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:stellar_fe/services/vod_document_api.dart';

// Contract test: VodDocumentApi maps the backend JSON (see
// StellarWeb.Api.VodDocumentController) onto the FE models, and surfaces the
// `{error: <code>}` bodies as VodDocException.
VodDocumentApi _apiReturning(Object json, {int status = 200}) {
  final client = MockClient(
    (req) async => http.Response(
      jsonEncode(json),
      status,
      headers: {'content-type': 'application/json'},
    ),
  );
  return VodDocumentApi(client: client, baseUrl: 'http://test');
}

void main() {
  test('requestUploadUrl parses uid + upload_url', () async {
    final api = _apiReturning({
      'data': {
        'uid': 'cf-uid-123',
        'upload_url': 'https://upload.cloudflarestream.com/one-time',
      },
    });

    final ticket = await api.requestUploadUrl('tok');

    expect(ticket.uid, 'cf-uid-123');
    expect(ticket.uploadUrl, 'https://upload.cloudflarestream.com/one-time');
  });

  test('createDocument maps the persisted Document', () async {
    final api = _apiReturning({
      'data': {
        'id': 'doc-1',
        'title': 'Welcome & course intro',
        'url': 'https://videodelivery.net/cf-uid-123/manifest/video.m3u8',
        'mime_type': 'video/mp4',
        'description': 'A short intro.',
        'course_id': null,
      },
    });

    final doc = await api.createDocument('tok', uid: 'cf-uid-123', title: 'x');

    expect(doc.id, 'doc-1');
    expect(doc.title, 'Welcome & course intro');
    expect(doc.url, 'https://videodelivery.net/cf-uid-123/manifest/video.m3u8');
    expect(doc.mimeType, 'video/mp4');
    expect(doc.courseId, isNull);
  });

  test('fetchStatus maps ready state', () async {
    final api = _apiReturning({
      'data': {
        'uid': 'cf-uid-123',
        'state': 'ready',
        'ready_to_stream': true,
        'duration_seconds': 42,
        'hls_url': 'https://videodelivery.net/cf-uid-123/manifest/video.m3u8',
      },
    });

    final status = await api.fetchStatus('tok', 'cf-uid-123');

    expect(status.isReady, isTrue);
    expect(status.isProcessing, isFalse);
    expect(status.durationSeconds, 42);
  });

  test('a still-processing video is not ready', () async {
    final api = _apiReturning({
      'data': {'uid': 'u', 'state': 'inprogress', 'ready_to_stream': false},
    });

    final status = await api.fetchStatus('tok', 'u');

    expect(status.isReady, isFalse);
    expect(status.isProcessing, isTrue);
  });

  test('no_organization surfaces a UI-ready VodDocException', () async {
    final api = _apiReturning({'error': 'no_organization'}, status: 422);

    expect(
      () => api.createDocument('tok', uid: 'u', title: 't'),
      throwsA(
        isA<VodDocException>().having(
          (e) => e.message,
          'message',
          contains('organization'),
        ),
      ),
    );
  });

  test('video_service_not_configured surfaces a VodDocException', () async {
    final api = _apiReturning({
      'error': 'video_service_not_configured',
    }, status: 503);

    expect(() => api.requestUploadUrl('tok'), throwsA(isA<VodDocException>()));
  });
}
