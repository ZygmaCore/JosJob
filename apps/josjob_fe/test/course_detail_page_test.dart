import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:josjob_fe/explore/explore_page.dart';
import 'package:josjob_fe/services/courses_api.dart';
import 'support/workflow_fonts.dart';

void main() {
  configureWorkflowFonts();
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'course footer leaves space for details at width $width even when loading fails',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(
            home: CourseDetailPage(
              courseId: 'course',
              initial: CourseSummary(
                id: 'course',
                title: 'Practical skills',
                description: 'A course with an ordered curriculum.',
                industries: [],
                classCount: 0,
                currency: 'usd',
                hasCurriculum: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
        final footer = find.byWidget(scaffold.bottomNavigationBar!);
        expect(tester.getSize(footer).height, lessThan(100));
        expect(tester.getRect(footer).bottom, 1000);
        expect(
          tester.getSize(find.byWidget(scaffold.body!)).height,
          greaterThan(700),
        );
        expect(find.text('Course details'), findsOneWidget);
        expect(find.text('Retry course details'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('open-course-curriculum')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
