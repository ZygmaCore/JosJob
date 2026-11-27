import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:josjob_fe/dashboard/dashboard_page.dart';
import 'support/workflow_fonts.dart';
import 'package:josjob_fe/landing/landing_page_ascent.dart';

void main() {
  configureWorkflowFonts();
  for (final width in [320.0, 1440.0]) {
    testWidgets('dashboard opens and closes Ask AI at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardPage(initialView: 'career', initialTab: 'coaching'),
        ),
      );
      await tester.pumpAndSettle();
      final open = find.byKey(const ValueKey('ask-ai-open'));
      expect(open, findsOneWidget);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ask-ai-send')), findsOneWidget);
      final close = find.byKey(const ValueKey('ask-ai-close'));
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ask-ai-send')), findsNothing);
      expect(open, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('landing preserves navigation while removing Ask AI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: JosjobLandingPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('landing-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-nav-jobs')), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-nav-journey')), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-nav-faq')), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-ai-open')), findsNothing);
    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('landing-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Ask AI'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
