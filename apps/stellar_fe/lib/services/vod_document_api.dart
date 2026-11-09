import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'api_config.dart';

// =========================================================================
// ATVETI STELLAR — VOD-as-Document API client
//
// Uploads a video via Cloudflare Stream and persists it as a StellarDoc
// **Document** (mime_type video, course_id null) — NOT a lecture. Mirrors the
// backend StellarWeb.Api.VodDocumentController (Bearer access token):
//
//   POST /api/vod/documents/upload-url   -> { data: {uid, upload_url} }
//   POST /api/vod/documents              -> { data: {id, title, url, mime_type, …} }
//   GET  /api/vod/documents/:uid/status  -> { data: {state, ready_to_stream, …} }
//
// The picked file is uploaded straight to Cloudflare's one-time [upload_url]
// (it never passes through our backend) via [uploadToCloudflare], exactly like
// the lecture flow in vod_api.dart — but the persisted entity is a Document.
//
// UI-ready English error messages; mirrors the shape of vod_api.dart.
// =========================================================================

String? _nonEmpty(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

int _toInt(dynamic v) => (v is num) ? v.toInt() : 0;

/// A VOD saved as a Document. [url] is the HLS playback URL; [mimeType] marks
/// it as video media (e.g. "video/mp4").
class VodDocument {
  final String id;
  final String title;
  final String url;
  final String? mimeType;
  final String? description;
  final String? courseId;

  const VodDocument({
    required this.id,
    required this.title,
    required this.url,
    this.mimeType,
    this.description,
    this.courseId,
  });

  factory VodDocument.fromJson(Map<String, dynamic> j) => VodDocument(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
    mimeType: _nonEmpty(j['mime_type']),
    description: _nonEmpty(j['description']),
    courseId: _nonEmpty(j['course_id']),
  );
}

/// The one-time Cloudflare direct-upload ticket from [requestUploadUrl]: the
/// video [uid] (to poll status / build the Document) and the [uploadUrl] to
/// POST the file bytes to.
class VodUploadTicket {
  final String uid;
  final String uploadUrl;
  const VodUploadTicket({required this.uid, required this.uploadUrl});
}

/// Live Cloudflare transcode status for a video [uid] (read straight from the
/// provider — the Document itself carries no processing state).
class VodDocStatus {
  final String uid;

  /// "pendingupload" | "queued" | "downloading" | "inprogress" | "ready" | "error"
  final String state;
  final bool readyToStream;
  final int durationSeconds;
  final String? hlsUrl;

  const VodDocStatus({
    required this.uid,
    required this.state,
    required this.readyToStream,
    this.durationSeconds = 0,
    this.hlsUrl,
  });

  bool get isReady => readyToStream || state == 'ready';
  bool get isFailed => state == 'error';
  bool get isProcessing => !isReady && !isFailed;

  factory VodDocStatus.fromJson(Map<String, dynamic> j) => VodDocStatus(
    uid: (j['uid'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    readyToStream: j['ready_to_stream'] == true,
    durationSeconds: _toInt(j['duration_seconds']),
    hlsUrl: _nonEmpty(j['hls_url']),
  );
}

/// A failed VOD-document API call carrying a UI-ready [message].
class VodDocException implements Exception {
  final String message;
  final int? statusCode;
  const VodDocException(this.message, {this.statusCode});

  @override
  String toString() => 'VodDocException($statusCode): $message';
}

const String _kGenericError = 'Something went wrong saving the video.';
const String _kNetworkError =
    "Can't reach the server. Check your connection and try again.";
const String _kTimeoutError =
    'The server took too long to respond. Please try again.';

class VodDocumentApi {
  VodDocumentApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);
  static const Duration _uploadTimeout = Duration(minutes: 8);

  /// Mints a one-time Cloudflare direct-upload URL (no Document created yet).
  Future<VodUploadTicket> requestUploadUrl(String token) async {
    final body = await _post(
      '/api/vod/documents/upload-url',
      token: token,
      body: const {},
    );
    final data = _requireData(body);
    final uid = _nonEmpty(data['uid']);
    final uploadUrl = _nonEmpty(data['upload_url']);
    if (uid == null || uploadUrl == null) {
      throw const VodDocException('The server did not return an upload URL.');
    }
    return VodUploadTicket(uid: uid, uploadUrl: uploadUrl);
  }

  /// Uploads the picked video [bytes] straight to Cloudflare's one-time
  /// [uploadUrl] (multipart field `file`). No auth header — the URL is
  /// pre-signed, and the file never touches our backend.
  Future<void> uploadToCloudflare(
    String uploadUrl,
    List<int> bytes, {
    String filename = 'video.mp4',
    String contentType = 'video/mp4',
  }) async {
    final mediaType = _parseMediaType(contentType);
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: mediaType,
        ),
      );

    final http.StreamedResponse res;
    try {
      res = await _client.send(request).timeout(_uploadTimeout);
    } on TimeoutException {
      throw const VodDocException(
        'The upload took too long. Try a smaller file or a better connection.',
      );
    } catch (_) {
      throw const VodDocException(_kNetworkError);
    }
    // Drain the body so the connection is released regardless of status
    // (Cloudflare returns 200 with an empty body on success).
    await res.stream.drain<void>();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw VodDocException(
        'The video upload was rejected (${res.statusCode}). Please try again.',
        statusCode: res.statusCode,
      );
    }
  }

  /// Persists the uploaded video (referenced by [uid]) as a Document.
  Future<VodDocument> createDocument(
    String token, {
    required String uid,
    required String title,
    String? mimeType,
    String? description,
  }) async {
    final body = await _post(
      '/api/vod/documents',
      token: token,
      body: {
        'uid': uid,
        'title': title,
        if (mimeType != null && mimeType.isNotEmpty) 'mime_type': mimeType,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return VodDocument.fromJson(_requireData(body));
  }

  /// Reads the live Cloudflare transcode status for [uid]; poll until
  /// `ready`/`error`.
  Future<VodDocStatus> fetchStatus(String token, String uid) async {
    final body = await _get('/api/vod/documents/$uid/status', token: token);
    return VodDocStatus.fromJson(_requireData(body));
  }

  void close() => _client.close();

  // ---- internals -------------------------------------------------------

  MediaType _parseMediaType(String contentType) {
    final parts = contentType.split('/');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('video', 'mp4');
  }

  Map<String, dynamic> _requireData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return data.cast<String, dynamic>();
    throw const VodDocException(_kGenericError);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    required String token,
  }) async {
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const VodDocException(_kTimeoutError);
    } catch (_) {
      throw const VodDocException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _tryDecode(res.body) ?? const {};
    }
    throw VodDocException(
      _errorMessage(res.statusCode, _tryDecode(res.body)),
      statusCode: res.statusCode,
    );
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
      throw const VodDocException(_kTimeoutError);
    } catch (_) {
      throw const VodDocException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _tryDecode(res.body) ?? const {};
    }
    throw VodDocException(
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
      case 'no_organization':
        return 'You need to belong to an organization to upload a video.';
      case 'title_required':
        return 'Please give the video a title.';
      case 'uid_required':
        return 'The upload reference was missing. Please try again.';
      case 'create_failed':
        return "Couldn't save the video. Check the details and try again.";
      case 'not_found':
        return 'That video is no longer available.';
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
