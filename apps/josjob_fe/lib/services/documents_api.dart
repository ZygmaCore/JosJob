import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart' show AuthException;

// =========================================================================
// JosJob — Documents + access-sharing API client
//
// Browse the documents you can access and manage a document's share list
// (Google-Docs-style: the uploader/owner decides who can access it). Mirrors
// JosjobWeb.Api.DocumentController (Bearer access token):
//
//   GET    /api/documents                      -> { data: [ {…, relationship, can_manage} ] }
//   GET    /api/documents/:id                  -> { data: {…} }
//   GET    /api/documents/:id/grants           -> { data: [ {…grant} ] }   (managers)
//   POST   /api/documents/:id/grants           -> { data: {…grant} }       (share via email)
//   DELETE /api/documents/:id/grants/:grant_id -> { data: {deleted:true} } (revoke)
//
// On a 401 the calls throw the shared [AuthException] (statusCode 401) so
// Session.runAuthed rotates the refresh token and retries; other failures
// throw [DocApiException] with a UI-ready message.
// =========================================================================

String? _nonEmpty(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _parseDate(dynamic v) {
  final s = _nonEmpty(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// A document the caller can see. [relationship] is one of `owner` | `org` |
/// `admin` | `shared`; [canManage] gates the share controls.
class DocItem {
  final String id;
  final String title;
  final String url;
  final String? mimeType;
  final String? description;
  final String? courseId;
  final String? ownerId;
  final String relationship;
  final bool canManage;

  const DocItem({
    required this.id,
    required this.title,
    required this.url,
    required this.relationship,
    required this.canManage,
    this.mimeType,
    this.description,
    this.courseId,
    this.ownerId,
  });

  bool get isVideo => (mimeType ?? '').startsWith('video/');
  bool get sharedWithMe => relationship == 'shared';

  factory DocItem.fromJson(Map<String, dynamic> j) => DocItem(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
    relationship: (j['relationship'] ?? 'shared').toString(),
    canManage: j['can_manage'] == true,
    mimeType: _nonEmpty(j['mime_type']),
    description: _nonEmpty(j['description']),
    courseId: _nonEmpty(j['course_id']),
    ownerId: _nonEmpty(j['owner_id']),
  );
}

/// One entry on a document's share list. [active] is the server's computed
/// verdict (allow AND within the valid window); [validUntil] null = no expiry.
class DocGrant {
  final String id;
  final String documentId;
  final String userId;
  final String? email;
  final String? fullName;
  final bool allow;
  final bool active;
  final DateTime? validFrom;
  final DateTime? validUntil;

  const DocGrant({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.allow,
    required this.active,
    this.email,
    this.fullName,
    this.validFrom,
    this.validUntil,
  });

  factory DocGrant.fromJson(Map<String, dynamic> j) => DocGrant(
    id: (j['id'] ?? '').toString(),
    documentId: (j['document_id'] ?? '').toString(),
    userId: (j['user_id'] ?? '').toString(),
    email: _nonEmpty(j['email']),
    fullName: _nonEmpty(j['full_name']),
    allow: j['allow'] == true,
    active: j['active'] == true,
    validFrom: _parseDate(j['valid_from']),
    validUntil: _parseDate(j['valid_until']),
  );
}

/// A presigned upload ticket for a NON-video file (pdf/doc/…): PUT the raw
/// bytes to [uploadUrl], then create the Document with [publicUrl] as its `url`.
class DocUploadTicket {
  final String uploadUrl;
  final String publicUrl;
  final String key;
  final String method;

  const DocUploadTicket({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    this.method = 'PUT',
  });

  factory DocUploadTicket.fromJson(Map<String, dynamic> j) => DocUploadTicket(
    uploadUrl: (j['upload_url'] ?? '').toString(),
    publicUrl: (j['public_url'] ?? '').toString(),
    key: (j['key'] ?? '').toString(),
    method: (j['method'] ?? 'PUT').toString(),
  );
}

/// A failed documents API call carrying a UI-ready [message].
class DocApiException implements Exception {
  final String message;
  final int? statusCode;
  const DocApiException(this.message, {this.statusCode});

  @override
  String toString() => 'DocApiException($statusCode): $message';
}

const String _kGenericError = 'Something went wrong. Please try again.';
const String _kNetworkError =
    "Can't reach the server. Check your connection and try again.";
const String _kTimeoutError =
    'The server took too long to respond. Please try again.';

class DocumentsApi {
  DocumentsApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);
  static const Duration _uploadTimeout = Duration(minutes: 8);

  /// Documents the caller can access (owned, org-admin, or shared with them).
  Future<List<DocItem>> listDocuments(String token) async {
    final body = await _get('/api/documents', token: token);
    return _list(body).map(DocItem.fromJson).toList();
  }

  /// The share list for [docId] (owner / org-admin / superuser only).
  Future<List<DocGrant>> listGrants(String token, String docId) async {
    final body = await _get('/api/documents/$docId/grants', token: token);
    return _list(body).map(DocGrant.fromJson).toList();
  }

  /// Grant (or update, by upsert) access for [email] to [docId]. [validUntil]
  /// null = never expires; [allow] false disables without removing the entry.
  Future<DocGrant> addGrant(
    String token, {
    required String docId,
    required String email,
    bool allow = true,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    final body = await _post(
      '/api/documents/$docId/grants',
      token: token,
      body: {
        'email': email,
        'allow': allow,
        if (validFrom != null)
          'valid_from': validFrom.toUtc().toIso8601String(),
        if (validUntil != null)
          'valid_until': validUntil.toUtc().toIso8601String(),
      },
    );
    return DocGrant.fromJson(_requireData(body));
  }

  /// Revoke a share by [grantId].
  Future<void> deleteGrant(
    String token, {
    required String docId,
    required String grantId,
  }) async {
    await _delete('/api/documents/$docId/grants/$grantId', token: token);
  }

  // ---- upload (non-video: pdf/doc/…) -----------------------------------

  /// Mints a presigned upload URL for a non-video file. The bytes are PUT
  /// straight to object storage (never through our backend).
  Future<DocUploadTicket> requestUploadUrl(
    String token, {
    String? filename,
  }) async {
    final body = await _post(
      '/api/documents/upload-url',
      token: token,
      body: {if (filename != null && filename.isNotEmpty) 'filename': filename},
    );
    return DocUploadTicket.fromJson(_requireData(body));
  }

  /// PUTs the raw file [bytes] straight to the presigned [uploadUrl]. No auth
  /// header — the URL is pre-signed. [contentType] is sent as the object type.
  Future<void> uploadBytes(
    String uploadUrl,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    final http.Response res;
    try {
      res = await _client
          .put(
            Uri.parse(uploadUrl),
            headers: {'Content-Type': contentType},
            body: bytes,
          )
          .timeout(_uploadTimeout);
    } on TimeoutException {
      throw const DocApiException(
        'The upload took too long. Try a smaller file or a better connection.',
      );
    } catch (_) {
      throw const DocApiException(_kNetworkError);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DocApiException(
        'The file upload was rejected (${res.statusCode}). Please try again.',
        statusCode: res.statusCode,
      );
    }
  }

  /// Persists a standalone Document (course_id null) pointing at [url].
  Future<DocItem> createDocument(
    String token, {
    required String title,
    required String url,
    String? mimeType,
    String? description,
  }) async {
    final body = await _post(
      '/api/documents',
      token: token,
      body: {
        'title': title,
        'url': url,
        if (mimeType != null && mimeType.isNotEmpty) 'mime_type': mimeType,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return DocItem.fromJson(_requireData(body));
  }

  void close() => _client.close();

  // ---- internals -------------------------------------------------------

  List<Map<String, dynamic>> _list(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    }
    throw const DocApiException(_kGenericError);
  }

  Map<String, dynamic> _requireData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return data.cast<String, dynamic>();
    throw const DocApiException(_kGenericError);
  }

  Future<Map<String, dynamic>> _get(String path, {required String token}) =>
      _send('GET', path, token: token);

  Future<Map<String, dynamic>> _post(
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) => _send('POST', path, token: token, body: body);

  Future<Map<String, dynamic>> _delete(String path, {required String token}) =>
      _send('DELETE', path, token: token);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    final http.Response res;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      final future = switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers, body: encoded),
        _ => _client.get(uri, headers: headers),
      };
      res = await future.timeout(_timeout);
    } on TimeoutException {
      throw const DocApiException(_kTimeoutError);
    } catch (_) {
      throw const DocApiException(_kNetworkError);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _tryDecode(res.body) ?? const {};
    }
    // 401 → throw AuthException so Session.runAuthed refreshes + retries.
    if (res.statusCode == 401) {
      throw const AuthException('Your session has expired.', statusCode: 401);
    }
    throw DocApiException(
      _errorMessage(res.statusCode, _tryDecode(res.body)),
      statusCode: res.statusCode,
    );
  }

  // Map the backend's `{error: <code>}` responses to UI-ready English.
  String _errorMessage(int status, Map<String, dynamic>? body) {
    switch (body?['error']?.toString()) {
      case 'user_not_found':
        return 'No account was found for that email address.';
      case 'cannot_grant_owner':
        return 'That person already owns this document.';
      case 'email_required':
        return 'Enter an email address to share with.';
      case 'invalid_datetime':
        return 'That date looks invalid. Please pick it again.';
      case 'invalid_window':
        return "The expiry can't be before the start date.";
      case 'forbidden':
        return "You don't have permission to manage this document's access.";
      case 'not_found':
        return 'That document is no longer available.';
      case 'create_failed':
        return "Couldn't save the document. Please try again.";
      case 'delete_failed':
        return "Couldn't remove the share. Please try again.";
      case 'storage_not_configured':
        return 'File uploads are not set up on the server yet.';
      case 'storage_error':
        return 'The storage service is unavailable right now. Please try again.';
      case 'no_organization':
        return 'You need to belong to an organization to upload a document.';
      case 'title_required':
        return 'Please give the document a title.';
      case 'url_required':
        return 'The upload reference was missing. Please try again.';
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
