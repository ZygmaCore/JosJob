import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:josjob_fe/shared/learning_navigation.dart';
import 'package:josjob_fe/services/ui_preferences.dart';

void main() {
  test(
    'course links retain a local job return destination through authentication',
    () {
      const origin = '/jobs/job-1?apply=1';
      final course = Uri(
        path: '/courses/course-1',
        queryParameters: {'return_to': origin},
      ).toString();
      expect(AuthContinuation.validate(course), course);
      expect(learningReturnPath(origin), origin);
      expect(learningReturnLabel(origin), 'Back to application');
      expect(learningReturnLabel('/jobs/job-1'), 'Back to job');
      for (final invalid in [
        'https://example.com/jobs/1',
        '//example.com/jobs/1',
        '/login',
        '/learn/course-1',
        '/jobs/1#fragment',
      ]) {
        expect(learningReturnPath(invalid), isNull);
      }
    },
  );
  for (final existing in [true, false]) {
    testWidgets(
      'learning return ${existing ? 'preserves an existing application' : 'restores a cold application route'}',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        var applicationBuilds = 0;
        Widget application() {
          applicationBuilds++;
          return Scaffold(body: Text('Application draft $applicationBuilds'));
        }

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: existing
                ? application()
                : const Scaffold(body: Text('Initial route')),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => application(),
            ),
          ),
        );
        if (existing) {
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/jobs/1?apply=1'),
              builder: (_) => application(),
            ),
          );
          await tester.pumpAndSettle();
        }
        final before = applicationBuilds;
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/learn/1'),
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => returnFromLearning(context, '/jobs/1?apply=1'),
                child: const Text('Back to application'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Back to application'));
        await tester.pumpAndSettle();
        expect(
          find.text('Application draft ${existing ? before : before + 1}'),
          findsOneWidget,
        );
        expect(applicationBuilds, existing ? before : before + 1);
      },
    );
  }
}
