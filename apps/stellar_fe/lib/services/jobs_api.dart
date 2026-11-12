import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart' show AuthException;

class JobListing {
  final String id, title, company, organizationId, description, location;
  final String industry, employmentType, workMode, currency, status;
  final List<String> requirements, highlights;
  final int? salaryMin, salaryMax;
  final DateTime? postedAt;
  final bool synthetic, canManage;

  const JobListing({
    required this.id,
    required this.title,
    required this.company,
    required this.organizationId,
    required this.description,
    required this.location,
    required this.industry,
    required this.employmentType,
    required this.workMode,
    required this.currency,
    required this.status,
    required this.requirements,
    required this.highlights,
    this.salaryMin,
    this.salaryMax,
    this.postedAt,
    this.synthetic = false,
    this.canManage = false,
  });

  factory JobListing.fromJson(Map<String, dynamic> j) => JobListing(
    id: j['id'] as String,
    title: j['title'] as String,
    company: j['company'] as String,
    organizationId: j['organization_id'] as String,
    description: j['description'] as String,
    location: j['location'] as String,
    industry: j['industry'] as String,
    employmentType: j['employment_type'] as String,
    workMode: j['work_mode'] as String,
    currency: j['currency'] as String,
    status: j['status'] as String,
    requirements: List<String>.from(j['requirements'] as List? ?? const []),
    highlights: List<String>.from(j['highlights'] as List? ?? const []),
    salaryMin: (j['salary_min'] as num?)?.toInt(),
    salaryMax: (j['salary_max'] as num?)?.toInt(),
    postedAt: DateTime.tryParse(j['posted_at']?.toString() ?? ''),
    synthetic: j['synthetic'] == true,
    canManage: j['can_manage'] == true,
  );

  String get salaryLabel {
    String amount(int value) => value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    if (salaryMin == null && salaryMax == null) return 'Salary not disclosed';
    final range = salaryMin != null && salaryMax != null
        ? '${amount(salaryMin!)}–${amount(salaryMax!)}'
        : salaryMin != null
        ? 'from ${amount(salaryMin!)}'
        : 'up to ${amount(salaryMax!)}';
    return '$currency $range / month';
  }
}

class JobOrganization {
  final String id, name;
  final bool canPost, canManage;
  const JobOrganization({
    required this.id,
    required this.name,
    required this.canPost,
    required this.canManage,
  });
  factory JobOrganization.fromJson(Map<String, dynamic> j) => JobOrganization(
    id: j['id'] as String,
    name: j['name'] as String,
    canPost: j['can_post'] == true,
    canManage: j['can_manage'] == true,
  );
}

class JobsPageResult {
  final List<JobListing> jobs;
  final List<JobOrganization> organizations;
  final int page, total, totalPages;
  const JobsPageResult({
    required this.jobs,
    required this.organizations,
    required this.page,
    required this.total,
    required this.totalPages,
  });
}

class JobsApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic> fields;
  const JobsApiException(
    this.message, {
    this.statusCode,
    this.fields = const {},
  });
  @override
  String toString() => message;
}

/// All calls use Session.runAuthed so an expired access token is refreshed once.
class JobsApi {
  final http.Client _client;
  final String _baseUrl;
  JobsApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<JobsPageResult> list(
    String token, {
    Map<String, String> filters = const {},
    int page = 1,
  }) async {
    final body = await _send(
      'GET',
      '/api/jobs',
      token,
      query: {...filters, 'page': '$page', 'page_size': '12'},
    );
    final meta = body['meta'] as Map<String, dynamic>;
    return JobsPageResult(
      jobs: (body['data'] as List)
          .map((j) => JobListing.fromJson(j as Map<String, dynamic>))
          .toList(),
      organizations: (body['organizations'] as List)
          .map((j) => JobOrganization.fromJson(j as Map<String, dynamic>))
          .toList(),
      page: meta['page'] as int,
      total: meta['total'] as int,
      totalPages: meta['total_pages'] as int,
    );
  }

  Future<JobListing> get(String token, String id) async {
    final body = await _send(
      'GET',
      '/api/jobs/${Uri.encodeComponent(id)}',
      token,
    );
    return JobListing.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<JobListing> save(
    String token,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    final body = await _send(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/api/jobs' : '/api/jobs/${Uri.encodeComponent(id)}',
      token,
      body: values,
    );
    return JobListing.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String token, String id) async {
    await _send('DELETE', '/api/jobs/${Uri.encodeComponent(id)}', token);
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    String token, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $token',
      });
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        throw const AuthException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode == 204) return {};
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          403 =>
            'You do not have permission to manage jobs in this organization.',
          404 => 'This job is no longer available.',
          400 => 'Some filters are invalid. Check the values and try again.',
          422 => 'Check the job details and try again.',
          _ => 'Jobs could not be loaded. Please try again.',
        };
        throw JobsApiException(
          message,
          statusCode: response.statusCode,
          fields: decoded['fields'] is Map
              ? Map<String, dynamic>.from(decoded['fields'] as Map)
              : const {},
        );
      }
      return decoded;
    } on TimeoutException {
      throw const JobsApiException('The request timed out. Please try again.');
    } on http.ClientException {
      throw const JobsApiException(
        'Cannot reach the server. Check your connection and try again.',
      );
    } on FormatException {
      throw const JobsApiException(
        'The server returned an invalid response. Please try again.',
      );
    }
  }
}
