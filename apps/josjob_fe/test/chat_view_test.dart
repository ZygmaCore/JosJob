import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/chat/chat_page.dart';
import 'package:josjob_fe/services/chat_api.dart';
import 'support/workflow_fixtures.dart';
import 'support/workflow_fonts.dart';

Future<T> _auth<T>(Future<T> Function(String) call) => call('token');
void main() {
  configureWorkflowFonts();
  for (final kind in ['application', 'coaching']) {
    testWidgets(
      '$kind uses the shared chat and preserves a failed draft for an idempotent retry',
      (tester) async {
        final keys = <String>[];
        final api = ChatApi(
          baseUrl: 'http://test',
          client: MockClient((request) async {
            expect(request.url.path, '/api/chats/$kind/context-1/messages');
            if (request.method == 'GET') {
              return http.Response(jsonEncode(chatJson()), 200);
            }
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            keys.add(body['client_id'] as String);
            if (keys.length == 1) {
              return http.Response('{"error":"unavailable"}', 503);
            }
            return http.Response(
              jsonEncode({
                'data': messageJson(
                  id: '2',
                  body: body['body'] as String,
                  clientId: keys.last,
                  senderId: 'candidate',
                ),
              }),
              201,
            );
          }),
        );
        addTearDown(api.close);
        await tester.pumpWidget(
          MaterialApp(
            home: ChatPage(
              kind: kind,
              contextId: 'context-1',
              title: 'Conversation',
              api: api,
              authorize: _auth,
              realtime: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('shared-chat')), findsOneWidget);
        expect(find.byKey(const ValueKey('message-1')), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('chat-draft')),
          'Can we discuss the next step?',
        );
        await tester.tap(find.byKey(const ValueKey('chat-send')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chat-error')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
              .controller!
              .text,
          'Can we discuss the next step?',
        );
        await tester.tap(find.byKey(const ValueKey('chat-send')));
        await tester.pumpAndSettle();
        expect(keys, hasLength(2));
        expect(keys.first, keys.last);
        expect(find.byKey(const ValueKey('message-2')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
              .controller!
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'read-only history remains visible while the composer is removed',
    (tester) async {
      final api = ChatApi(
        baseUrl: 'http://test',
        client: MockClient(
          (_) async => http.Response(jsonEncode(chatJson(canSend: false)), 200),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            kind: 'coaching',
            contextId: 'cancelled',
            title: 'Conversation',
            api: api,
            authorize: _auth,
            realtime: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('message-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-read-only')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-send')), findsNothing);
    },
  );
  testWidgets(
    'loading earlier messages uses the cursor and retains current history',
    (tester) async {
      final api = ChatApi(
        baseUrl: 'http://test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.queryParameters['before'] == '2'
                  ? chatJson(messages: [messageJson(id: '1')])
                  : chatJson(
                      messages: [messageJson(id: '2')],
                      nextBefore: '2',
                    ),
            ),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            kind: 'application',
            contextId: 'id',
            title: 'Conversation',
            api: api,
            authorize: _auth,
            realtime: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-load-older')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('message-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-load-older')), findsNothing);
    },
  );
}
