import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/applications/applications_view.dart';
import 'package:josjob_fe/services/applications_api.dart';
import 'package:josjob_fe/services/jobs_api.dart';
import 'jobs_api_test.dart' show jobJson;
import 'support/workflow_fixtures.dart';
import 'support/workflow_fonts.dart';

Future<T> _auth<T>(Future<T> Function(String) call) => call('token');
void main() {
  configureWorkflowFonts();
  testWidgets(
    'application submission previews the profile and requires sharing consent',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? submission;
      final api = ApplicationsApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/application-suggestions')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'status': 'matched',
                  'source': 'saved_profile',
                  'matched_skills': ['Elixir'],
                  'missing_skills': [],
                  'uncovered_skills': [],
                  'courses': [],
                },
              }),
              200,
            );
          }
          if (request.url.path == '/api/me/cv') {
            return http.Response(
              jsonEncode({'data': applicationJson()['profile']}),
              200,
            );
          }
          if (request.method == 'POST') {
            submission = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return http.Response(jsonEncode({'data': applicationJson()}), 200);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ApplyPage(
            job: JobListing.fromJson(jobJson()),
            api: api,
            authorize: _auth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile to share'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('submit-application')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('application-cover-letter')),
        'Please consider my application.',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('application-consent')),
      );
      await tester.tap(find.byKey(const ValueKey('application-consent')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-application')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-application')));
      await tester.pumpAndSettle();
      expect(submission, {
        'cover_letter': 'Please consider my application.',
        'consent': true,
      });
      expect(find.byKey(const ValueKey('application-detail')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('empty persisted applications show an honest empty state', (
    tester,
  ) async {
    final api = ApplicationsApi(
      baseUrl: 'http://test',
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode(applicationList(empty: true)), 200),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ApplicationsView(api: api, authorize: _auth),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('applications-empty')), findsOneWidget);
    expect(find.text('Front Office Associate'), findsNothing);
    expect(
      find.byKey(const ValueKey('application-application-1')),
      findsNothing,
    );
  });
  testWidgets(
    'employer opens an application and confirms a server-checked stage change',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var status = 'applied';
      final api = ApplicationsApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          if (request.url.path == '/api/applications') {
            return http.Response(
              jsonEncode(applicationList(hiring: true)),
              200,
            );
          }
          if (request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['expected_status'], 'applied');
            status = body['status'] as String;
          }
          return http.Response(
            jsonEncode({
              'data': applicationJson(status: status, manager: true),
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ApplicationsView(api: api, authorize: _auth, hiring: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('application-application-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('application-detail')), findsOneWidget);
      expect(find.byKey(const ValueKey('application-chat')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('application-stage-reviewing')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-application-stage')));
      await tester.pumpAndSettle();
      expect(status, 'reviewing');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
