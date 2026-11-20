import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/dashboard/overview/learning_overview_view.dart';
import 'package:josjob_fe/services/learning_overview_api.dart';
import 'learning_overview_api_test.dart' show overviewJson;

class _TestFonts implements AssetManifest {
  @override
  List<String> listAssets() => [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
  ].map((weight) => 'test-fonts/Poppins-$weight.ttf').toList();
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

Future<T> _authorize<T>(Future<T> Function(String) call) => call('test-token');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final bytes = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    font_loader.assetManifest = _TestFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      data,
    ) async {
      final key = utf8.decode(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return key.startsWith('test-fonts/') ? bytes : null;
    });
  });
  tearDownAll(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
    font_loader.assetManifest = null;
    font_loader.clearCache();
  });

  Future<void> showOverview(
    WidgetTester tester,
    LearningOverviewApi api, {
    bool organization = false,
    Future<void> Function(LearningCourse)? open,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LearningOverviewView(
              api: api,
              authorize: _authorize,
              organization: organization,
              firstName: 'Ayu',
              onOpenCourse: open,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders API enrollments and refreshes after opening a real course',
    (tester) async {
      var active = 2;
      String? opened;
      final api = LearningOverviewApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'data': overviewJson(active: active)}),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await showOverview(
        tester,
        api,
        open: (course) async {
          opened = course.id;
          active = 3;
        },
      );
      expect(
        find.byKey(const ValueKey('learning-enrollment-enrollment-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('learning-course-python')),
        findsOneWidget,
      );
      expect(find.text('Evening SQL · Enrolled'), findsOneWidget);
      final view = find.descendant(
        of: find.byKey(const ValueKey('learning-course-python')),
        matching: find.text('View course'),
      );
      await tester.ensureVisible(view);
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(opened, 'python');
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('learning-stat-active_enrollments')),
            )
            .data,
        '3',
      );
      expect(find.textContaining('Module 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows empty data honestly at mobile width and retries failed requests',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final api = LearningOverviewApi(
        client: MockClient((_) async {
          if (++calls == 1) return http.Response('{}', 503);
          final data = overviewJson();
          data['stats'] = {
            'active_enrollments': 0,
            'completed_enrollments': 0,
            'available_courses': 0,
            'upcoming_sessions': 0,
          };
          for (final key in ['enrollments', 'courses', 'upcoming_sessions']) {
            data[key] = [];
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      addTearDown(api.close);
      await showOverview(tester, api);
      expect(
        find.byKey(const ValueKey('learning-overview-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('learning-stat-active_enrollments')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('retry-learning-overview')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('learning-overview-error')),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('learning-stat-active_enrollments')),
            )
            .data,
        '0',
      );
      expect(find.textContaining('You haven’t enrolled'), findsOneWidget);
      expect(find.textContaining('Maya Chen'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'organization shows persisted completion counts, including no-enrollment members',
    (tester) async {
      final data = overviewJson(organization: true);
      (data['members'] as List).add({
        'id': 'new',
        'name': 'New learner',
        'enrollment_count': 0,
        'completed_count': 0,
      });
      final api = LearningOverviewApi(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'data': data}), 200),
        ),
      );
      addTearDown(api.close);
      await showOverview(tester, api, organization: true);
      expect(find.byKey(const ValueKey('learning-team')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('learning-completion-member-1')),
        findsOneWidget,
      );
      expect(find.text('No enrollments'), findsOneWidget);
      expect(find.text('1 of 2 enrollments completed'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('learning-enrollments')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing scope discards a late response from the previous scope',
    (tester) async {
      final pending = Completer<http.Response>();
      final api = LearningOverviewApi(
        client: MockClient((request) async {
          if (request.url.queryParameters['scope'] == 'learner') {
            return pending.future;
          }
          return http.Response(
            jsonEncode({'data': overviewJson(organization: true)}),
            200,
          );
        }),
      );
      addTearDown(api.close);
      Future<void> pump(bool org) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LearningOverviewView(
                api: api,
                authorize: _authorize,
                organization: org,
              ),
            ),
          ),
        ),
      );
      await pump(false);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('learning-overview-loading')),
        findsOneWidget,
      );
      await pump(true);
      await tester.pumpAndSettle();
      pending.complete(
        http.Response(jsonEncode({'data': overviewJson()}), 200),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('learning-team')), findsOneWidget);
      expect(find.byKey(const ValueKey('learning-enrollments')), findsNothing);
    },
  );
}
