import 'workflow_client.dart';

class StudyApi extends WorkflowClient {
  StudyApi({super.client, super.baseUrl});
  Future<Map<String, dynamic>> get(String token, String id) async =>
      (await request(
            'GET',
            '/api/catalog/courses/${Uri.encodeComponent(id)}/study',
            token,
          ))['data']
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> enroll(String token, String id) async =>
      (await request(
            'POST',
            '/api/catalog/courses/${Uri.encodeComponent(id)}/study/enroll',
            token,
          ))['data']
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> complete(
    String token,
    String id,
    String lesson,
    Map<String, int> answers,
  ) async =>
      (await request(
            'POST',
            '/api/catalog/courses/${Uri.encodeComponent(id)}/study/lessons/${Uri.encodeComponent(lesson)}/complete',
            token,
            data: {'answers': answers},
          ))['data']
          as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> mine(String token) async =>
      ((await request('GET', '/api/me/course-studies', token))['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}
