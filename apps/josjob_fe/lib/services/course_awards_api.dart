import 'workflow_client.dart';

class CourseAwardsApi extends WorkflowClient {
  CourseAwardsApi({super.client, super.baseUrl});
  Future<Map<String, dynamic>> preview(String token, String id) async =>
      (await request(
            'GET',
            '/api/me/course-awards/${Uri.encodeComponent(id)}',
            token,
          ))['data']
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> confirm(
    String token,
    String id,
    String name,
  ) async =>
      (await request(
            'POST',
            '/api/me/course-awards/${Uri.encodeComponent(id)}/confirm',
            token,
            data: {'confirm_cv': true, 'expected_name': name},
          ))['data']
          as Map<String, dynamic>;
}
