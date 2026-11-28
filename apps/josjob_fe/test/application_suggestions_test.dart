import 'dart:async';
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

Map<String, dynamic> suggestionsJson({
  String status = 'gap',
  bool course = true,
}) => {
  'status': status,
  'source': 'analyzed_cv',
  'matched_skills': ['Elixir'],
  'missing_skills': status == 'gap' ? ['SQL', 'Docker'] : [],
  'uncovered_skills': status == 'gap'
      ? (course ? ['Docker'] : ['SQL', 'Docker'])
      : [],
  'courses': status == 'gap' && course
      ? [
          {
            'id': 'sql-course',
            'title': 'SQL essentials',
            'description': 'Learn SQL',
            'industries': [],
            'class_count': 1,
            'currency': 'usd',
            'price_cents': 2500,
            'matched_skills': ['SQL'],
          },
        ]
      : [],
};

void main() {
  configureWorkflowFonts();

  Future<void> openApply(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) suggestionResponse, {
    bool expandLearning = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApplicationsApi(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/application-suggestions')) {
          expect(request.headers['authorization'], 'Bearer token');
          expect(request.method, 'GET');
          return suggestionResponse(request);
        }
        if (request.url.path == '/api/me/cv') {
          return http.Response(
            jsonEncode({'data': applicationJson()['profile']}),
            200,
          );
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
    if (expandLearning) {
      await tester.pump();
      await tester.pump();
      final optional = find.byKey(
        const ValueKey('optional-application-learning'),
      );
      await tester.ensureVisible(optional);
      await tester.tap(optional);
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
    'skill tags filter courses and open matching coach sessions without leaving Apply',
    (tester) async {
      final data = suggestionsJson();
      data['coaches'] = [
        {
          'id': 'docker-coach',
          'display_name': 'Container coach',
          'headline': 'Practical container skills',
          'bio': 'Learn containers with guided practice.',
          'expertise': ['Docker'],
          'status': 'approved',
          'session_minutes': 30,
          'matched_skills': ['Docker'],
          'slots': [
            {
              'id': 'docker-slot',
              'starts_at': '2030-01-01T10:00:00Z',
              'ends_at': '2030-01-01T10:30:00Z',
            },
          ],
        },
      ];
      await openApply(
        tester,
        (_) async => http.Response(jsonEncode({'data': data}), 200),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('suggested-course-sql-course')),
        findsOneWidget,
      );
      final chip = find.byKey(const ValueKey('gap-skill-Docker'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('suggested-course-sql-course')),
        findsNothing,
      );
      final coach = find.byKey(const ValueKey('suggested-coach-docker-coach'));
      await tester.ensureVisible(coach);
      await tester.tap(coach);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('book-slot-docker-slot')),
        findsOneWidget,
      );
      expect(find.text('Container coach'), findsWidgets);
      await tester.tap(find.byTooltip('Close profile'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('application-skill-gap')),
        findsOneWidget,
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('suggested-course-sql-course')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing skills suggest real courses, explain uncovered skills and open the catalog',
    (tester) async {
      await openApply(
        tester,
        (_) async =>
            http.Response(jsonEncode({'data': suggestionsJson()}), 200),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('application-skill-gap')),
        findsOneWidget,
      );
      expect(find.text('SQL'), findsOneWidget);
      expect(find.text('Docker'), findsOneWidget);
      expect(find.textContaining('last analyzed CV'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('application-suggestions-uncovered')),
        findsOneWidget,
      );
      final course = find.byKey(const ValueKey('suggested-course-sql-course'));
      await tester.ensureVisible(course);
      await tester.tap(course);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Course details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('skill gaps do not block submitting an application', (
    tester,
  ) async {
    await openApply(
      tester,
      (_) async => http.Response(jsonEncode({'data': suggestionsJson()}), 200),
      expandLearning: false,
    );
    await tester.pumpAndSettle();
    final consent = find.byKey(const ValueKey('application-consent'));
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pump();
    final submit = find.byKey(const ValueKey('submit-application'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('application-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final status in ['matched', 'cv_required', 'no_requirements']) {
    testWidgets('$status shows an honest state without course suggestions', (
      tester,
    ) async {
      await openApply(
        tester,
        (_) async => http.Response(
          jsonEncode({'data': suggestionsJson(status: status)}),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey('application-suggestions-${status.replaceAll('_', '-')}'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('application-skill-gap')), findsNothing);
      expect(
        find.byKey(const ValueKey('suggested-course-sql-course')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'no matching catalog course keeps the gap visible without inventing a course',
    (tester) async {
      await openApply(
        tester,
        (_) async => http.Response(
          jsonEncode({'data': suggestionsJson(course: false)}),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('application-skill-gap')),
        findsOneWidget,
      );
      expect(
        find.text('No matching course is available yet for: SQL, Docker.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('suggested-course-sql-course')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'loading and failure leave applying available; retry refreshes suggestions',
    (tester) async {
      final pending = Completer<http.Response>();
      var attempts = 0;
      await openApply(tester, (_) async {
        attempts++;
        if (attempts == 1) return pending.future;
        return http.Response(jsonEncode({'data': suggestionsJson()}), 200);
      });
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('application-suggestions-loading')),
        findsOneWidget,
      );
      final consent = find.byKey(const ValueKey('application-consent'));
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('submit-application')),
            )
            .onPressed,
        isNotNull,
      );
      pending.complete(http.Response('{"error":"unavailable"}', 503));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('application-suggestions-error')),
        findsOneWidget,
      );
      final retry = find.byKey(const ValueKey('retry-application-suggestions'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        find.byKey(const ValueKey('application-skill-gap')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
