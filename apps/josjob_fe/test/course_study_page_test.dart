import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/learning/course_study_page.dart';
import 'package:josjob_fe/services/study_api.dart';

Future<T> authorize<T>(Future<T> Function(String) call) => call('token');

Map<String, dynamic> courseData(int stage, {bool failed = false}) => {
  'id': 'course',
  'title': 'Backend foundations',
  'enrolled': stage >= 0,
  'progress': stage < 0 ? 0 : (stage * 100 / 3).round(),
  'completed_count': stage < 0 ? 0 : stage,
  'lesson_count': 3,
  'resume_lesson_id': stage < 0
      ? 'l0'
      : stage == 3
      ? null
      : 'l$stage',
  if (failed) 'assessment': {'passed': false, 'score': 0},
  'lessons': [
    for (var i = 0; i < 3; i++)
      {
        'id': 'l$i',
        'title': ['Request flow', 'Guided practice', 'Knowledge check'][i],
        'module_title': i == 0 ? 'Foundations' : 'Practice and assessment',
        'position': i + 1,
        'kind': i == 2 ? 'quiz' : 'reading',
        'completed': stage > i,
        'unlocked': stage >= i,
        'body': stage >= i
            ? 'Original lesson content. Follow the request from the router to the context and database.'
            : null,
        'questions': i == 2 && stage >= 2
            ? [
                {
                  'id': 'q1',
                  'prompt': 'Where is durable data stored?',
                  'options': ['PostgreSQL', 'Only cache'],
                },
                {
                  'id': 'q2',
                  'prompt': 'What should you verify?',
                  'options': ['Saved result', 'Nothing'],
                },
              ]
            : [],
      },
  ],
};

void main() {
  testWidgets(
    'mobile learner starts a course, completes ordered lessons, retries quiz and resumes saved progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var stage = -1;
      final api = StudyApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token');
          var failed = false;
          if (request.url.path.endsWith('/enroll')) stage = 0;
          if (request.url.path.endsWith('/complete')) {
            final lesson = request.url.path.split('/').reversed.skip(1).first;
            if (lesson == 'l2') {
              final answers =
                  (jsonDecode(request.body) as Map)['answers'] as Map;
              failed = answers['q1'] != 0 || answers['q2'] != 0;
              if (!failed) stage = 3;
            } else {
              stage++;
            }
          }
          return http.Response(
            jsonEncode({'data': courseData(stage, failed: failed)}),
            200,
          );
        }),
      );
      addTearDown(api.close);
      Widget page() => MaterialApp(
        home: CourseStudyPage(
          courseId: 'course',
          api: api,
          authorize: authorize,
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('start-course-study')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-course-study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-mobile-curriculum')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close curriculum'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('study-lesson-l2')))
            .onTap,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('study-lesson-l0')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close curriculum'), findsNothing);
      for (var i = 0; i < 2; i++) {
        final complete = find.byKey(const ValueKey('complete-study-lesson'));
        await tester.ensureVisible(complete);
        await tester.pumpAndSettle();
        await tester.tap(complete);
        await tester.pumpAndSettle();
      }
      expect(find.text('2/3 lessons · 67%'), findsOneWidget);
      for (final option in ['Only cache', 'Nothing']) {
        final item = find.text(option);
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();
      }
      final submit = find.byKey(const ValueKey('complete-study-lesson'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.textContaining('Score: 0%'), findsOneWidget);
      for (final option in ['PostgreSQL', 'Saved result']) {
        final item = find.text(option);
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('study-course-complete')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('3/3 lessons · 100%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('study-course-complete')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('complete-study-lesson')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('review-completed-course')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('course-results')), findsNothing);
      expect(
        find.byKey(const ValueKey('back-to-course-results')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'completed course prioritizes returning to its job and hides curriculum until review',
    (tester) async {
      final api = StudyApi(
        baseUrl: 'http://test',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'data': courseData(3)}), 200),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: CourseStudyPage(
            courseId: 'course',
            api: api,
            authorize: authorize,
            returnTo: '/jobs/1?apply=1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('return-to-job-after-learning')),
        findsOneWidget,
      );
      expect(find.text('Back to application'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('open-mobile-curriculum')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('complete-study-lesson')), findsNothing);
      expect(
        find.byKey(const ValueKey('review-completed-course')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
