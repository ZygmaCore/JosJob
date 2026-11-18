import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/applications/applications_view.dart';
import 'package:josjob_fe/services/applications_api.dart';
import 'support/workflow_fixtures.dart';
import 'support/workflow_fonts.dart';

Future<T> _auth<T>(Future<T> Function(String) call) => call('token');

void main() {
  configureWorkflowFonts();
  testWidgets('hiring and stage selection survive a desktop to mobile resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    final api = ApplicationsApi(
      baseUrl: 'http://test',
      client: MockClient((r) async {
        requests.add(r.url);
        return http.Response(jsonEncode(applicationList(hiring: true)), 200);
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
    await tester.tap(
      find.byKey(const ValueKey('application-filter-reviewing')),
    );
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['scope'], 'hiring');
    expect(requests.last.queryParameters['status'], 'reviewing');
    final requestCount = requests.length;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('applications-stage-filter')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('application-scope-hiring')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('applications-stage-filter')),
          )
          .initialValue,
      'reviewing',
    );
    expect(requests.length, requestCount);
    expect(tester.takeException(), isNull);
  });
}
