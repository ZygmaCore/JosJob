import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/learning/course_award_card.dart';
import 'package:josjob_fe/services/course_awards_api.dart';
import 'support/workflow_fonts.dart';

Future<T> auth<T>(Future<T> Function(String) fn) => fn('token');
Map<String, dynamic> award({
  bool issued = false,
  String name = 'Ari Pratama',
}) => {
  'id': 'award',
  'title': 'SQL foundations',
  'skill_tags': ['SQL', 'Docker'],
  'name_locked': issued,
  'recipient_name': issued ? name : null,
  'cv_name': name,
  'issued_on': issued ? '2026-11-27' : null,
  'credential_id': issued ? 'JOSJOB-AWARD' : null,
};

void main() {
  configureWorkflowFonts();
  testWidgets(
    'certificate needs explicit CV confirmation then displays the locked name without edit controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var issued = 0;
      final api = CourseAwardsApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token');
          if (request.method == 'POST') {
            issued++;
            expect(jsonDecode(request.body), {
              'confirm_cv': true,
              'expected_name': 'Ari Pratama',
            });
          }
          return http.Response(
            jsonEncode({'data': award(issued: request.method == 'POST')}),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourseAwardCard(award: award(), api: api, authorize: auth),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('claim-course-certificate')));
      await tester.pumpAndSettle();
      expect(find.text('Confirm certificate name'), findsOneWidget);
      expect(find.text('Ari Pratama'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('issue-locked-certificate'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(issued, 0);
      await tester.tap(find.byKey(const ValueKey('confirm-certificate-cv')));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(issued, 1);
      expect(
        find.byKey(const ValueKey('locked-certificate-name')),
        findsOneWidget,
      );
      expect(find.text('Ari Pratama'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('claim-course-certificate')),
        findsNothing,
      );
      expect(find.text('Edit'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale CV name requires a new preview and new confirmation', (
    tester,
  ) async {
    var previews = 0;
    final api = CourseAwardsApi(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'error': 'cv_name_changed'}), 409);
        }
        previews++;
        return http.Response(
          jsonEncode({
            'data': award(name: previews == 1 ? 'Ari Old' : 'Ari New'),
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseAwardCard(award: award(), api: api, authorize: auth),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('claim-course-certificate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-certificate-cv')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('issue-locked-certificate')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('certificate-claim-error')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('claim-course-certificate')));
    await tester.pumpAndSettle();
    expect(find.text('Ari New'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('issue-locked-certificate')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('locked-certificate-name')), findsNothing);
  });
}
