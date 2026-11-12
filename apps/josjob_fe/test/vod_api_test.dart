import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:josjob_fe/services/vod_api.dart';

// Contract test: the VodApi client maps the backend JSON (see
// JosjobWeb.Api.CourseController / LectureController) onto the FE models.
// The wire keys stay `lecture(s)`/`lecture_count`; the client models them as
// VOD videos.
VodApi _apiReturning(Object json, {int status = 200}) {
  final client = MockClient(
    (req) async => http.Response(
      jsonEncode(json),
      status,
      headers: {'content-type': 'application/json'},
    ),
  );
  return VodApi(client: client, baseUrl: 'http://test');
}

void main() {
  test('fetchVideo parses hls_url, checkpoints and transcript', () async {
    final api = _apiReturning({
      'data': {
        'id': 'l1',
        'title': 'Arrays, Lists & Big-O',
        'description': 'A recorded session.',
        'state': 'ready',
        'hls_url': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        'duration_seconds': 596,
        'format': 'hls (h264/aac)',
        'checkpoints': [
          {'title': 'Intro', 'start_seconds': 0},
          {'title': 'Arrays', 'start_seconds': 95},
        ],
        'transcript': {
          'language': 'en',
          'segments': [
            {'start_seconds': 0, 'end_seconds': 40, 'text': 'Welcome.'},
            {'start_seconds': 40, 'end_seconds': 95, 'text': 'Loops.'},
          ],
        },
      },
    });

    final video = await api.fetchVideo('l1');

    expect(video.title, 'Arrays, Lists & Big-O');
    expect(video.isReady, isTrue);
    expect(video.hlsUrl, 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');
    expect(video.durationSeconds, 596);
    expect(video.checkpoints, hasLength(2));
    expect(video.checkpoints[1].startSeconds, 95);
    expect(video.transcript, hasLength(2));
    expect(video.transcript.first.text, 'Welcome.');
    expect(video.transcript.first.endSeconds, 40);
  });

  test('a still-processing video is not ready and has no url', () async {
    final api = _apiReturning({
      'data': {'id': 'l2', 'title': 'Trees', 'state': 'transcribing'},
    });

    final video = await api.fetchVideo('l2');

    expect(video.isReady, isFalse);
    expect(video.isProcessing, isTrue);
    expect(video.hlsUrl, isNull);
  });

  test('fetchCourses maps the list payload', () async {
    final api = _apiReturning({
      'data': [
        {
          'id': 'c1',
          'title': 'Introduction to Data Structures',
          'description': 'd',
          'lecture_count': 3,
        },
      ],
    });

    final courses = await api.fetchCourses();

    expect(courses, hasLength(1));
    expect(courses.first.title, 'Introduction to Data Structures');
    expect(courses.first.videoCount, 3);
  });

  test('a 404 surfaces a VodException', () async {
    final api = _apiReturning({'error': 'not_found'}, status: 404);
    expect(() => api.fetchVideo('missing'), throwsA(isA<VodException>()));
  });
}
