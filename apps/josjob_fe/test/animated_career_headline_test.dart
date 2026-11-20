import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:josjob_fe/landing/landing_page_ascent.dart';

Widget headline({
  bool reduced = false,
  bool enabled = true,
  double width = 520,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: TickerMode(
        enabled: enabled,
        child: SizedBox(
          width: width,
          child: AnimatedCareerHeadline(
            style: const TextStyle(fontSize: 40, height: 1.14),
          ),
        ),
      ),
    ),
  ),
);
Finder word(String text) => find.byKey(ValueKey('career-word-$text.'));

void main() {
  testWidgets('changes every 500ms while reserving stable text width', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(headline(width: 280));
    final frame = find.byKey(const ValueKey('career-word-frame'));
    final size = tester.getSize(frame);
    expect(word('ambitions'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 499));
    expect(word('dreams'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(word('dreams'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 260));
    expect(word('ambitions'), findsNothing);
    expect(tester.getSize(frame), size);
    await tester.pump(const Duration(milliseconds: 239));
    expect(word('ideas'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(word('ideas'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Big ambitions. Clear next steps.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('loops automatically while the headline is hovered', (
    tester,
  ) async {
    await tester.pumpWidget(headline());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    await mouse.moveTo(tester.getCenter(find.byType(AnimatedCareerHeadline)));
    await tester.pump(const Duration(milliseconds: 500));
    for (final next in [
      'dreams',
      'ideas',
      'goals',
      'plans',
      'ambitions',
      'dreams',
    ]) {
      expect(word(next), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 260));
      expect(word(next), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 240));
    }
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps the headline static', (tester) async {
    await tester.pumpWidget(headline(reduced: true));
    await tester.pump(const Duration(seconds: 4));
    expect(word('ambitions'), findsOneWidget);
    expect(word('dreams'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('covered routes pause and disposal cancels the timer', (
    tester,
  ) async {
    await tester.pumpWidget(headline(enabled: false));
    await tester.pump(const Duration(seconds: 2));
    expect(word('ambitions'), findsOneWidget);
    expect(word('dreams'), findsNothing);
    await tester.pumpWidget(headline());
    await tester.pump(const Duration(milliseconds: 500));
    expect(word('dreams'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
