// THROWAWAY — verifies the two-phase register flow. Delete after running.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:josjob_fe/auth/auth_page.dart';

void main() {
  testWidgets('register is two-phase: type gate, then form + google', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump(const Duration(milliseconds: 300));

    // Phase 1 — registration type + Continue; sign-up fields NOT shown yet.
    expect(find.text('Registration type'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Create account'), findsNothing);

    // Pick Personal, then Continue.
    await tester.tap(find.text('Personal').first);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));

    // Phase 2 — "Registering as" banner + full form + Google; picker is gone.
    expect(find.text('Registering as'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Registration type'), findsNothing);

    // "Change" returns to the type gate.
    await tester.tap(find.text('Change'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Registration type'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });
}
