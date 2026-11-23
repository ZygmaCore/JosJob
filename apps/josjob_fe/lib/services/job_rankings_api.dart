import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import 'auth_api.dart' show AuthException;

class RankingException implements Exception {
  final String message;
  const RankingException(this.message);
  @override
  String toString() => message;
}

/// All CV traffic goes through the authenticated backend, never an AI provider.
class JobRankingsApi {
  final http.Client _client;
  final String _base;
  JobRankingsApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _base = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, dynamic>> upload(
    String token,
    Uint8List bytes,
    String filename, {
    required bool consent,
  }) async {
    if (!consent) {
      throw const RankingException('Please agree to CV processing first.');
    }
    if (bytes.isEmpty || bytes.length > 10000000) {
      throw const RankingException('Choose a non-empty PDF up to 10 MB.');
    }
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_base/api/rag/cv/extractions'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['consent'] = 'true'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: MediaType('application', 'pdf'),
            ),
          );
    return _send(request);
  }

  Future<Map<String, dynamic>> extraction(String token, String id) => _send(
    http.Request(
      'GET',
      Uri.parse('$_base/api/rag/cv/extractions/${Uri.encodeComponent(id)}'),
    )..headers['Authorization'] = 'Bearer $token',
  );

  Future<Map<String, dynamic>> rank(String token, String extractionId) => _send(
    http.Request('POST', Uri.parse('$_base/api/rag/analyses'))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({'extraction_id': extractionId, 'limit': 50}),
  );

  Future<Map<String, dynamic>> rankSaved(String token, String cvId) => _send(
    http.Request('POST', Uri.parse('$_base/api/rag/analyses'))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({'cv_id': cvId, 'limit': 50}),
  );

  Future<Map<String, dynamic>> _send(http.BaseRequest request) async {
    try {
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(const Duration(minutes: 3));
      if (response.statusCode == 401) {
        throw const AuthException('Please sign in again.', statusCode: 401);
      }
      if (response.statusCode >= 400) {
        throw RankingException(switch (response.statusCode) {
          404 => 'This extraction has expired. Upload your CV again.',
          413 => 'Choose a PDF up to 10 MB.',
          415 => 'Choose a valid PDF file.',
          422 =>
            'Your CV could not be read. Try a clearer PDF with selectable text.',
          429 => 'The analysis queue is full. Please try again shortly.',
          _ => 'CV matching is unavailable. Please try again.',
        });
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    } on TimeoutException {
      throw const RankingException('The request timed out. Please try again.');
    } on FormatException {
      throw const RankingException(
        'The server returned an invalid response. Please try again.',
      );
    } on TypeError {
      throw const RankingException(
        'The server returned an invalid response. Please try again.',
      );
    } on http.ClientException {
      throw const RankingException('Check your connection and try again.');
    }
  }

  void close() => _client.close();
}
