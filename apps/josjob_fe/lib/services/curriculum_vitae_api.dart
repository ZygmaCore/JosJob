import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api.dart' show AuthException;
import 'certificates_api.dart' show LearnerCertificate;

class CvException implements Exception {
  final String message;
  const CvException(this.message);
  @override
  String toString() => message;
}

class CvPdfDocument {
  final String id, title, url;
  CvPdfDocument.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      title = j['title'] as String,
      url = j['url'] as String;
}

class CvBackgroundEntry {
  final String? name,
      position,
      degree,
      major,
      country,
      industry,
      type,
      from,
      to;
  final bool internship;
  CvBackgroundEntry.fromJson(Map<String, dynamic> j)
    : name = j['name'] as String?,
      position = j['position'] as String?,
      degree = j['degree'] as String?,
      major = j['major'] as String?,
      country = j['country'] as String?,
      industry = j['industry'] as String?,
      type = j['type'] as String?,
      from = j['from'] as String?,
      to = j['to'] as String?,
      internship = j['internship'] == true;
  String get period => from != null && to != null
      ? '$from – $to'
      : from != null
      ? 'From $from'
      : to != null
      ? 'Until $to'
      : 'Dates not provided';
}

class CurriculumVitaeData {
  final List<String> earnedSkillTags, editableSkills;
  final String fullName, email;
  final String? phone, location, headline, summary;
  final List<String> skills;
  final List<CvBackgroundEntry> experience, education;
  final List<LearnerCertificate> certificates;
  final List<CvPdfDocument> pdfDocuments;
  final CvPdfDocument? resumeDocument;
  CurriculumVitaeData.fromJson(Map<String, dynamic> j)
    : earnedSkillTags = List<String>.from(
        j['earned_skill_tags'] as List? ?? [],
      ),
      editableSkills = List<String>.from(
        j['editable_skills'] as List? ?? j['skills'] as List,
      ),
      fullName = (j['identity'] as Map)['full_name'] as String,
      email = (j['identity'] as Map)['email'] as String,
      phone = (j['identity'] as Map)['phone'] as String?,
      location = (j['identity'] as Map)['location'] as String?,
      headline = j['headline'] as String?,
      summary = j['summary'] as String?,
      skills = List<String>.from(j['skills'] as List),
      experience = (j['experience'] as List)
          .map((v) => CvBackgroundEntry.fromJson(v as Map<String, dynamic>))
          .toList(),
      education = (j['education'] as List)
          .map((v) => CvBackgroundEntry.fromJson(v as Map<String, dynamic>))
          .toList(),
      certificates = (j['certificates'] as List)
          .map((v) => LearnerCertificate.fromJson(v as Map<String, dynamic>))
          .toList(),
      pdfDocuments = (j['pdf_documents'] as List)
          .map((v) => CvPdfDocument.fromJson(v as Map<String, dynamic>))
          .toList(),
      resumeDocument = j['resume_document'] == null
          ? null
          : CvPdfDocument.fromJson(
              j['resume_document'] as Map<String, dynamic>,
            );
}

class CurriculumVitaeApi {
  final http.Client _client;
  final String _base;
  CurriculumVitaeApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _base = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');
  Future<CurriculumVitaeData> fetch(String token) async {
    try {
      return CurriculumVitaeData.fromJson(
        (await _send('GET', token))['data'] as Map<String, dynamic>,
      );
    } on TypeError {
      throw const CvException(
        'The server returned unreadable CV data. Please try again.',
      );
    }
  }

  Future<void> save(String token, Map<String, dynamic> attrs) async {
    await _send('PATCH', token, attrs);
  }

  void close() => _client.close();
  Future<Map<String, dynamic>> _send(
    String method,
    String token, [
    Map<String, dynamic>? attrs,
  ]) async {
    try {
      final headers = {
        'accept': 'application/json',
        'authorization': 'Bearer $token',
        if (attrs != null) 'content-type': 'application/json',
      };
      final uri = Uri.parse('$_base/api/me/cv');
      final r =
          await (method == 'GET'
                  ? _client.get(uri, headers: headers)
                  : _client.patch(
                      uri,
                      headers: headers,
                      body: jsonEncode(attrs),
                    ))
              .timeout(const Duration(seconds: 25));
      if (r.statusCode == 401) {
        throw const AuthException('Please sign in again.', statusCode: 401);
      }
      if (r.statusCode >= 400) {
        throw CvException(
          r.statusCode == 422
              ? 'Check the CV fields and choose a PDF document you own.'
              : 'Your CV could not be loaded or saved. Please try again.',
        );
      }
      return jsonDecode(r.body) as Map<String, dynamic>;
    } on AuthException {
      rethrow;
    } on CvException {
      rethrow;
    } on TimeoutException {
      throw const CvException('The request timed out. Please try again.');
    } on http.ClientException {
      throw const CvException('Check your connection and try again.');
    } on FormatException {
      throw const CvException(
        'The server returned unreadable CV data. Please try again.',
      );
    } on TypeError {
      throw const CvException(
        'The server returned unreadable CV data. Please try again.',
      );
    }
  }
}
