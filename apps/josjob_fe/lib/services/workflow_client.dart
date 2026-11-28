import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api.dart' show AuthException;

typedef WorkflowAuthorize =
    Future<T> Function<T>(Future<T> Function(String) call);

class WorkflowException implements Exception {
  final String message;
  final int? statusCode;
  const WorkflowException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Auth is supplied by Session.runAuthed, including its refresh/retry behavior.
class WorkflowClient {
  final http.Client _client;
  final String baseUrl;
  WorkflowClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl;
  void close() => _client.close();
  Future<Map<String, dynamic>> request(
    String method,
    String path,
    String token, {
    Map<String, dynamic>? data,
    Map<String, String>? query,
  }) async {
    try {
      final request =
          http.Request(
              method,
              Uri.parse('$baseUrl$path').replace(queryParameters: query),
            )
            ..headers.addAll({
              'accept': 'application/json',
              'authorization': 'Bearer $token',
            });
      if (data != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(data);
      }
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        throw const AuthException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (body['error']) {
          'already_submitted' =>
            'You have already applied for this role. Open Applications to see your progress.',
          'consent_required' =>
            'Confirm that you want to share your saved profile with this employer.',
          'stale_application' =>
            'This application has changed. Refresh it before updating the stage.',
          'invalid_transition' =>
            'This stage change is no longer available. Refresh the application.',
          'invalid_interview_date' => 'Choose an interview time in the future.',
          'job_closed' => 'This role is no longer accepting applications.',
          'self_application' => 'You cannot apply to a role you manage.',
          'chat_read_only' =>
            'This conversation is now read-only. Your draft has been kept.',
          'idempotency_conflict' =>
            'This message could not be retried. Refresh the conversation.',
          'rate_limited' =>
            'Please wait a moment before sending more messages.',
          'not_found' =>
            'This record is unavailable or you no longer have access.',
          'enrollment_required' => 'Start learning to access this lesson.',
          'cv_confirmation_required' =>
            'Confirm that your CV and certificate name are correct.',
          'cv_name_changed' =>
            'Your CV name changed. Review the latest name and confirm again.',
          'cv_name_required' =>
            'Add your full name to your CV before issuing the certificate.',
          'certificate_locked' =>
            'The name on this certificate is permanently locked.',
          'lesson_locked' => 'Complete the previous lessons first.',
          'curriculum_unavailable' =>
            'The course curriculum has not been published yet.',
          'payment_required' =>
            'Complete checkout from the course page before starting this paid course.',
          'validation_failed' => 'Check your entry and try again.',
          _ => 'The request could not be completed. Please try again.',
        };
        throw WorkflowException(message, statusCode: response.statusCode);
      }
      return body;
    } on TimeoutException {
      throw const WorkflowException(
        'The request timed out. Your draft has been kept; you can retry.',
      );
    } on http.ClientException {
      throw const WorkflowException(
        'Cannot reach the server. Check your connection and retry.',
      );
    } on FormatException {
      throw const WorkflowException(
        'The server returned an unreadable response. Please retry.',
      );
    } on TypeError {
      throw const WorkflowException(
        'The server returned incomplete data. Please retry.',
      );
    }
  }
}
