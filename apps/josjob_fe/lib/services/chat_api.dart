import 'workflow_client.dart';

class ChatMessage {
  final String id, senderId, senderName, body, clientId;
  final DateTime createdAt;
  ChatMessage.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      senderId = j['sender_id'] as String,
      senderName = j['sender_name'] as String,
      body = j['body'] as String,
      clientId = j['client_id'] as String,
      createdAt = DateTime.parse(j['created_at'] as String);
}

class ChatHistory {
  final List<ChatMessage> messages;
  final String title, subtitle, selfId;
  final bool canSend;
  final String? nextBefore;
  ChatHistory.fromJson(Map<String, dynamic> j)
    : messages = (j['data'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      title = (j['thread'] as Map)['title'] as String,
      subtitle = (j['thread'] as Map)['subtitle'] as String,
      selfId = (j['thread'] as Map)['self_id'] as String,
      canSend = (j['thread'] as Map)['can_send'] as bool,
      nextBefore = j['next_before'] as String?;
}

class ChatApi extends WorkflowClient {
  ChatApi({super.client, super.baseUrl});
  String _path(String kind, String id) =>
      '/api/chats/${Uri.encodeComponent(kind)}/${Uri.encodeComponent(id)}/messages';
  Future<ChatHistory> history(
    String token,
    String kind,
    String id, {
    String? before,
  }) async => ChatHistory.fromJson(
    await request('GET', _path(kind, id), token, query: {'before': ?before}),
  );
  Future<ChatMessage> send(
    String token,
    String kind,
    String id,
    String body,
    String clientId,
  ) async => ChatMessage.fromJson(
    (await request(
          'POST',
          _path(kind, id),
          token,
          data: {'body': body, 'client_id': clientId},
        ))['data']
        as Map<String, dynamic>,
  );
}
