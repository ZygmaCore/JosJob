import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api.dart' show AuthException;
import 'jobs_api.dart';

class JobsOverviewException implements Exception {
  final String message;
  const JobsOverviewException(this.message);
  @override
  String toString() => message;
}

class JobsProfileSummary {
  final int onboardingProgress,
      skillCount,
      experienceCount,
      educationCount,
      certificatesSaved;
  final List<String> skills;
  JobsProfileSummary.fromJson(Map<String, dynamic> j)
    : onboardingProgress = (j['onboarding_progress'] as num).toInt(),
      skillCount = (j['skill_count'] as num).toInt(),
      experienceCount = (j['experience_count'] as num).toInt(),
      educationCount = (j['education_count'] as num).toInt(),
      certificatesSaved = (j['certificates_saved'] as num).toInt(),
      skills = List<String>.from(j['skills'] as List);
}

class JobsOverviewData {
  final int availableJobs, remoteJobs, fullTimeJobs, publishedLast7Days;
  final List<JobListing> jobs;
  final List<JobOrganization> organizations;
  final JobsProfileSummary profile;
  final bool matchingAvailable, applicationsAvailable;
  JobsOverviewData.fromJson(Map<String, dynamic> j)
    : availableJobs = ((j['stats'] as Map)['available_jobs'] as num).toInt(),
      remoteJobs = ((j['stats'] as Map)['remote_jobs'] as num).toInt(),
      fullTimeJobs = ((j['stats'] as Map)['full_time_jobs'] as num).toInt(),
      publishedLast7Days = ((j['stats'] as Map)['published_last_7_days'] as num)
          .toInt(),
      jobs = (j['jobs'] as List)
          .map((v) => JobListing.fromJson(v as Map<String, dynamic>))
          .toList(),
      organizations = (j['organizations'] as List)
          .map((v) => JobOrganization.fromJson(v as Map<String, dynamic>))
          .toList(),
      profile = JobsProfileSummary.fromJson(
        j['profile'] as Map<String, dynamic>,
      ),
      matchingAvailable = (j['capabilities'] as Map)['matching'] == true,
      applicationsAvailable =
          (j['capabilities'] as Map)['applications'] == true;
}

class JobsOverviewApi {
  final http.Client _client;
  final String _baseUrl;
  JobsOverviewApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');
  Future<JobsOverviewData> fetch(String token) async {
    try {
      final r = await _client
          .get(
            Uri.parse('$_baseUrl/api/me/jobs-overview'),
            headers: {
              'accept': 'application/json',
              'authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 401) {
        throw const AuthException('Please sign in again.', statusCode: 401);
      }
      if (r.statusCode >= 400) {
        throw const JobsOverviewException(
          'The jobs overview could not be loaded. Please try again.',
        );
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return JobsOverviewData.fromJson(json['data'] as Map<String, dynamic>);
    } on AuthException {
      rethrow;
    } on JobsOverviewException {
      rethrow;
    } on TimeoutException {
      throw const JobsOverviewException(
        'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const JobsOverviewException('Check your connection and try again.');
    } on FormatException {
      throw const JobsOverviewException(
        'The server returned unreadable overview data. Please try again.',
      );
    } on TypeError {
      throw const JobsOverviewException(
        'The server returned unreadable overview data. Please try again.',
      );
    }
  }

  void close() => _client.close();
}
