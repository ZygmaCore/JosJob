import 'workflow_client.dart';

const hiringStages = ['applied', 'reviewing', 'interview', 'offer', 'hired'];
String stageLabel(String stage) => stage.isEmpty
    ? 'All stages'
    : '${stage[0].toUpperCase()}${stage.substring(1)}';

class JobApplication {
  final String id, jobId, jobTitle, company, candidateName, status;
  final DateTime appliedAt;
  final DateTime? interviewAt;
  final bool canManage, canChat;
  final List<String> nextStatuses;
  final String coverLetter;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> history;
  JobApplication.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      jobId = j['job_id'] as String,
      jobTitle = j['job_title'] as String,
      company = j['company'] as String,
      candidateName = j['candidate_name'] as String,
      status = j['status'] as String,
      appliedAt = DateTime.parse(j['applied_at'] as String),
      interviewAt = DateTime.tryParse(j['interview_at']?.toString() ?? ''),
      canManage = j['can_manage'] == true,
      canChat = j['can_chat'] == true,
      nextStatuses = List<String>.from(j['next_statuses'] as List),
      coverLetter = j['cover_letter'] as String? ?? '',
      profile = Map<String, dynamic>.from(j['profile'] as Map? ?? {}),
      history = (j['history'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}

class ApplicationResults {
  final List<JobApplication> applications;
  final Map<String, int> counts;
  final bool canHire;
  final int page, totalPages, total;
  ApplicationResults.fromJson(Map<String, dynamic> j)
    : applications = (j['data'] as List)
          .map((a) => JobApplication.fromJson(a as Map<String, dynamic>))
          .toList(),
      counts = (j['counts'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      canHire = (j['organizations'] as List).isNotEmpty,
      page = (j['meta'] as Map)['page'] as int,
      totalPages = (j['meta'] as Map)['total_pages'] as int,
      total = (j['meta'] as Map)['total'] as int;
}

class ApplicationsApi extends WorkflowClient {
  ApplicationsApi({super.client, super.baseUrl});
  Future<ApplicationResults> list(
    String token, {
    String scope = 'mine',
    String status = '',
    int page = 1,
    String? jobId,
  }) async => ApplicationResults.fromJson(
    await request(
      'GET',
      '/api/applications',
      token,
      query: {
        'scope': scope,
        'status': status,
        'page': '$page',
        'job_id': ?jobId,
      },
    ),
  );
  Future<JobApplication> get(String token, String id) async =>
      JobApplication.fromJson(
        (await request(
              'GET',
              '/api/applications/${Uri.encodeComponent(id)}',
              token,
            ))['data']
            as Map<String, dynamic>,
      );
  Future<JobApplication> apply(
    String token,
    String jobId, {
    required String coverLetter,
    required bool consent,
  }) async => JobApplication.fromJson(
    (await request(
          'POST',
          '/api/jobs/${Uri.encodeComponent(jobId)}/applications',
          token,
          data: {'cover_letter': coverLetter, 'consent': consent},
        ))['data']
        as Map<String, dynamic>,
  );
  Future<JobApplication> advance(
    String token,
    JobApplication application,
    String status, {
    String note = '',
    DateTime? interviewAt,
  }) async => JobApplication.fromJson(
    (await request(
          'PATCH',
          '/api/applications/${Uri.encodeComponent(application.id)}',
          token,
          data: {
            'status': status,
            'expected_status': application.status,
            'note': note,
            if (interviewAt != null)
              'interview_at': interviewAt.toUtc().toIso8601String(),
          },
        ))['data']
        as Map<String, dynamic>,
  );
}
