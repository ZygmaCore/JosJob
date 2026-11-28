import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api.dart' show AuthException;

class CertificateException implements Exception {
  final String message;
  final int? statusCode;
  const CertificateException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class LearnerCertificate {
  final String? recipientName;
  final bool nameLocked;
  final List<String> skillTags;
  final String id, title, issuer, source;
  final String? issuedOn,
      expiresOn,
      credentialId,
      credentialUrl,
      recordedPeriod;
  final bool editable, expired;
  LearnerCertificate.fromJson(Map<String, dynamic> j)
    : recipientName = j['recipient_name'] as String?,
      nameLocked = j['name_locked'] == true,
      skillTags = List<String>.from(j['skill_tags'] as List? ?? []),
      id = j['id'] as String,
      title = j['title'] as String,
      issuer = j['issuer'] as String,
      source = j['source'] as String,
      issuedOn = j['issued_on'] as String?,
      expiresOn = j['expires_on'] as String?,
      credentialId = j['credential_id'] as String?,
      credentialUrl = j['credential_url'] as String?,
      recordedPeriod = j['recorded_period'] as String?,
      editable = j['editable'] == true,
      expired = j['expired'] == true;
}

class CertificatesApi {
  final http.Client _client;
  final String _baseUrl;
  CertificatesApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  Future<List<LearnerCertificate>> fetch(String token) async {
    try {
      return ((await _send('GET', '/api/me/certificates', token))['data']
              as List)
          .map((v) => LearnerCertificate.fromJson(v as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const CertificateException(
        'The server returned unreadable certificate data. Please try again.',
      );
    }
  }

  Future<void> save(
    String token,
    Map<String, dynamic> attrs, {
    String? id,
  }) async {
    await _send(
      id == null ? 'POST' : 'PATCH',
      '/api/me/certificates${id == null ? '' : '/${Uri.encodeComponent(id)}'}',
      token,
      attrs,
    );
  }

  Future<void> delete(String token, String id) async {
    await _send(
      'DELETE',
      '/api/me/certificates/${Uri.encodeComponent(id)}',
      token,
    );
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    String token, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'accept': 'application/json',
          'authorization': 'Bearer $token',
        });
      if (data != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(data);
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        throw const AuthException('Please sign in again.', statusCode: 401);
      }
      if (response.statusCode >= 400) {
        throw CertificateException(switch (response.statusCode) {
          404 =>
            'This certificate is no longer available. Refresh the list and try again.',
          422 =>
            'Check the title, issuer, dates and credential URL. Issue dates cannot be in the future, and expiry cannot precede issue.',
          _ => 'Certificates could not be updated. Please try again.',
        }, statusCode: response.statusCode);
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on AuthException {
      rethrow;
    } on CertificateException {
      rethrow;
    } on TimeoutException {
      throw const CertificateException(
        'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const CertificateException('Check your connection and try again.');
    } on FormatException {
      throw const CertificateException(
        'The server returned an unreadable response. Please try again.',
      );
    } on TypeError {
      throw const CertificateException(
        'The server returned an unreadable response. Please try again.',
      );
    }
  }
}
