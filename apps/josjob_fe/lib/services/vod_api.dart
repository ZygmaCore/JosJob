import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'api_config.dart';

// =========================================================================
// JosJob — Video-on-Demand (VOD) API client
//
// Thin JSON client for the public course/video read endpoints:
//   GET  /api/courses          -> { data: [ {id, title, description, lecture_count} ] }
//   GET  /api/courses/:id       -> { data: {id, title, description, lectures: [...]} }
//   GET  /api/lectures/:id      -> { data: {id, title, state, hls_url, duration_seconds,
//                                           format, checkpoints: [...], transcript: {...}} }
// (The backend still names these routes/keys `lecture(s)` on the wire; the
// client models them as VOD videos.)
//
// ...and the authenticated instructor upload endpoints (Bearer token):
//   POST /api/vod/courses                        -> create a course
//   POST /api/vod/courses/:course_id/lectures    -> mint a Cloudflare direct-
//        upload URL + a draft video ({lecture, upload_url})
//   POST /api/vod/lectures/:id/refresh           -> poll processing state
// The picked file is uploaded straight to Cloudflare's one-time [uploadUrl]
// (it never passes through our backend) via [uploadToCloudflare].
//
// Mirrors the shape/error-handling of auth_api.dart. UI-ready English errors.
// =========================================================================

String? _nonEmpty(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

double _toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;

int _toInt(dynamic v) => (v is num) ? v.toInt() : 0;

/// A course in the catalog. [videos] is populated only by [VodApi.fetchCourse]
/// (the list endpoint returns [videoCount] instead).
class VodCourse {
  final String id;
  final String title;
  final String? description;
  final int videoCount;
  final List<VodVideo> videos;

  const VodCourse({
    required this.id,
    required this.title,
    this.description,
    this.videoCount = 0,
    this.videos = const [],
  });

  factory VodCourse.fromJson(Map<String, dynamic> j) {
    final rawVideos = j['lectures'];
    final videos = rawVideos is List
        ? rawVideos
              .whereType<Map>()
              .map((m) => VodVideo.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const <VodVideo>[];
    return VodCourse(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: _nonEmpty(j['description']),
      videoCount: _toInt(j['lecture_count'] ?? videos.length),
      videos: videos,
    );
  }
}

/// A video (VOD unit). Summary fields come from the course endpoint; the
/// playback fields ([hlsUrl], [checkpoints], [transcript]) are filled by
/// [VodApi.fetchVideo].
class VodVideo {
  final String id;
  final String title;
  final String? description;
  final int position;

  /// Pipeline state: recorded | extracting_metadata | transcribing |
  /// checkpointing | ready | failed. Only `ready` videos are playable.
  final String state;
  final int durationSeconds;
  final String? hlsUrl;
  final String? format;
  final List<VideoCheckpoint> checkpoints;
  final List<TranscriptSegment> transcript;

  const VodVideo({
    required this.id,
    required this.title,
    this.description,
    this.position = 0,
    this.state = 'recorded',
    this.durationSeconds = 0,
    this.hlsUrl,
    this.format,
    this.checkpoints = const [],
    this.transcript = const [],
  });

  bool get isReady => state == 'ready';
  bool get isFailed => state == 'failed';
  bool get isProcessing => !isReady && !isFailed;

  factory VodVideo.fromJson(Map<String, dynamic> j) {
    final rawCheckpoints = j['checkpoints'];
    final checkpoints = rawCheckpoints is List
        ? rawCheckpoints
              .whereType<Map>()
              .map((m) => VideoCheckpoint.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const <VideoCheckpoint>[];

    final rawTranscript = j['transcript'];
    final segments = (rawTranscript is Map && rawTranscript['segments'] is List)
        ? (rawTranscript['segments'] as List)
              .whereType<Map>()
              .map((m) => TranscriptSegment.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const <TranscriptSegment>[];

    return VodVideo(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: _nonEmpty(j['description']),
      position: _toInt(j['position']),
      state: (j['state'] ?? 'recorded').toString(),
      durationSeconds: _toInt(j['duration_seconds']),
      hlsUrl: _nonEmpty(j['hls_url']),
      format: _nonEmpty(j['format']),
      checkpoints: checkpoints,
      transcript: segments,
    );
  }
}

/// A topic checkpoint (marker + seek target) on the video timeline.
class VideoCheckpoint {
  final String title;
  final int startSeconds;

  const VideoCheckpoint({required this.title, required this.startSeconds});

  factory VideoCheckpoint.fromJson(Map<String, dynamic> j) => VideoCheckpoint(
    title: (j['title'] ?? '').toString(),
    startSeconds: _toInt(j['start_seconds']),
  );
}

/// A timestamped transcript paragraph.
class TranscriptSegment {
  final double startSeconds;
  final double endSeconds;
  final String text;

  const TranscriptSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> j) =>
      TranscriptSegment(
        startSeconds: _toDouble(j['start_seconds']),
        endSeconds: _toDouble(j['end_seconds']),
        text: (j['text'] ?? '').toString(),
      );
}

/// The result of [VodApi.requestUpload]: the freshly-created draft video's
/// [videoId] plus the one-time Cloudflare [uploadUrl] to POST the file to.
class VodUploadTicket {
  final String videoId;
  final String uploadUrl;
  const VodUploadTicket({required this.videoId, required this.uploadUrl});
}

/// A failed VOD API call carrying a UI-ready [message].
class VodException implements Exception {
  final String message;
  final int? statusCode;
  const VodException(this.message, {this.statusCode});

  @override
  String toString() => 'VodException($statusCode): $message';
}

const String _kGenericError = 'Something went wrong loading the video.';
const String _kNotFoundError = 'This video is no longer available.';
const String _kNetworkError =
    "Can't reach the server. Check your connection and try again.";
const String _kTimeoutError =
    'The server took too long to respond. Please try again.';

class VodApi {
  VodApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);
  static const Duration _uploadTimeout = Duration(minutes: 8);

  Future<List<VodCourse>> fetchCourses() async {
    final body = await _get('/api/courses');
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => VodCourse.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<VodCourse> fetchCourse(String id) async {
    final body = await _get('/api/courses/$id');
    return VodCourse.fromJson(_requireData(body));
  }

  Future<VodVideo> fetchVideo(String id) async {
    final body = await _get('/api/lectures/$id');
    return VodVideo.fromJson(_requireData(body));
  }

  // ---- writes (instructor upload; Bearer token required) ---------------

  /// Creates an instructor-owned course. Returns it (id + title).
  Future<VodCourse> createCourse(
    String token, {
    required String title,
    String? description,
  }) async {
    final body = await _post(
      '/api/vod/courses',
      token: token,
      body: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return VodCourse.fromJson(_requireData(body));
  }

  /// Mints a one-time Cloudflare direct-upload URL for a new draft video
  /// under [courseId]. Returns the video id + the upload URL.
  Future<VodUploadTicket> requestUpload(
    String token, {
    required String courseId,
    required String title,
    int position = 0,
  }) async {
    final body = await _post(
      '/api/vod/courses/$courseId/lectures',
      token: token,
      body: {'title': title, 'position': position},
    );
    final data = _requireData(body);
    final video = data['lecture'];
    final uploadUrl = _nonEmpty(data['upload_url']);
    if (video is! Map || uploadUrl == null) {
      throw const VodException('The server did not return an upload URL.');
    }
    final id = _nonEmpty(video['id']);
    if (id == null) throw const VodException(_kGenericError);
    return VodUploadTicket(videoId: id, uploadUrl: uploadUrl);
  }

  /// Uploads the picked video [bytes] straight to Cloudflare's one-time
  /// [uploadUrl] (multipart field `file`). No auth header — the URL is
  /// pre-signed, and the file never touches our backend.
  Future<void> uploadToCloudflare(
    String uploadUrl,
    List<int> bytes, {
    String filename = 'video.mp4',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('video', 'mp4'),
        ),
      );

    final http.StreamedResponse res;
    try {
      res = await _client.send(request).timeout(_uploadTimeout);
    } on TimeoutException {
      throw const VodException(
        'The upload took too long. Try a smaller file or a better connection.',
      );
    } catch (_) {
      throw const VodException(_kNetworkError);
    }
    // Drain the body so the connection is released regardless of status
    // (Cloudflare returns 200 with an empty body on success).
    await res.stream.drain<void>();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw VodException(
        'The video upload was rejected (${res.statusCode}). Please try again.',
        statusCode: res.statusCode,
      );
    }
  }

  /// Asks the backend to pull the latest processing state from Cloudflare and
  /// sync it. Returns the refreshed video; poll until `ready`/`failed`.
  Future<VodVideo> refreshVideo(String token, String id) async {
    final body = await _post(
      '/api/vod/lectures/$id/refresh',
      token: token,
      body: const {},
    );
    return VodVideo.fromJson(_requireData(body));
  }

  void close() => _client.close();

  // ---- internals -------------------------------------------------------
  Map<String, dynamic> _requireData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return data.cast<String, dynamic>();
    throw const VodException(_kGenericError);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const VodException(_kTimeoutError);
    } catch (_) {
      throw const VodException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = _tryDecode(res.body);
      return decoded ?? const {};
    }
    if (res.statusCode == 404) {
      throw const VodException(_kNotFoundError, statusCode: 404);
    }
    throw VodException(_kGenericError, statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const VodException(_kTimeoutError);
    } catch (_) {
      throw const VodException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _tryDecode(res.body) ?? const {};
    }
    throw VodException(
      _errorMessage(res.statusCode, _tryDecode(res.body)),
      statusCode: res.statusCode,
    );
  }

  // Map the backend's `{error: <code>}` responses to UI-ready English.
  String _errorMessage(int status, Map<String, dynamic>? body) {
    switch (body?['error']?.toString()) {
      case 'video_service_not_configured':
        return 'Video uploads are not set up on the server yet.';
      case 'cloudflare_error':
        return 'The video service is unavailable right now. Please try again.';
      case 'create_failed':
        return "Couldn't create the video. Check the details and try again.";
      case 'not_found':
        return _kNotFoundError;
    }
    if (status == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    return _kGenericError;
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
      return null;
    } catch (_) {
      return null;
    }
  }
}
