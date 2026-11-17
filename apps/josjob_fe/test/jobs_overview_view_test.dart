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
import 'package:josjob_fe/dashboard/overview/jobs_overview_view.dart';
import 'package:josjob_fe/services/jobs_overview_api.dart';
import 'jobs_overview_api_test.dart' show jobsOverviewJson;

class _Fonts implements AssetManifest {
  @override
  List<String> listAssets() => [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
  ].map((w) => 'test-fonts/Poppins-$w.ttf').toList();
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

Future<T> _auth<T>(Future<T> Function(String) call) => call('test-token');
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final bytes = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    font_loader.assetManifest = _Fonts();
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
  Finder key(String value) => find.byKey(ValueKey(value));
  http.Response response({
    bool empty = false,
    int total = 12,
    int progress = 65,
  }) => http.Response(
    jsonEncode({
      'data': jobsOverviewJson(empty: empty, total: total, progress: progress),
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Widget app(JobsOverviewView child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets(
    'shows real summary data and refreshes after opening a listing or updating onboarding',
    (tester) async {
      var loads = 0, total = 12, progress = 65, browsed = false;
      String? opened;
      final api = JobsOverviewApi(
        client: MockClient((_) async {
          loads++;
          return response(total: total, progress: progress);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        app(
          JobsOverviewView(
            api: api,
            authorize: _auth,
            firstName: 'Ayu',
            onBrowseJobs: () => browsed = true,
            onOpenJob: (job) async {
              opened = job.id;
              total = 11;
            },
            onEditProfile: () async {
              progress = 75;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(key('jobs-stat-available')).data, '12');
      expect(find.text('Junior developer'), findsOneWidget);
      expect(find.text('Synthetic listing'), findsOneWidget);
      expect(find.text('82%'), findsNothing);
      expect(find.text('96% match'), findsNothing);
      expect(find.text('Open to work'), findsNothing);
      expect(find.text('Certifications verified'), findsNothing);
      await tester.ensureVisible(key('open-overview-job-job-1'));
      await tester.tap(key('open-overview-job-job-1'));
      await tester.pumpAndSettle();
      expect(opened, 'job-1');
      expect(loads, 2);
      expect(tester.widget<Text>(key('jobs-stat-available')).data, '11');
      await tester.ensureVisible(key('update-overview-profile'));
      await tester.tap(key('update-overview-profile'));
      await tester.pumpAndSettle();
      expect(find.text('Saved onboarding progress: 75%'), findsOneWidget);
      await tester.ensureVisible(key('browse-overview-jobs'));
      await tester.tap(key('browse-overview-jobs'));
      expect(browsed, true);
    },
  );

  testWidgets(
    'mobile empty accounts show honest zeros and unavailable application tracking',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = JobsOverviewApi(
        client: MockClient((_) async => response(empty: true, progress: 0)),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        app(JobsOverviewView(api: api, authorize: _auth)),
      );
      await tester.pumpAndSettle();
      expect(key('empty-overview-jobs'), findsOneWidget);
      expect(tester.widget<Text>(key('jobs-stat-available')).data, '0');
      expect(
        find.text(
          'Personalized matches and application tracking are coming soon.',
        ),
        findsOneWidget,
      );
      expect(find.text('Top matches for you'), findsNothing);
      expect(find.text('Front Office Associate'), findsNothing);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('retries API errors without presenting zeros while loading', (
    tester,
  ) async {
    var loads = 0;
    final pending = Completer<http.Response>();
    final api = JobsOverviewApi(
      client: MockClient((_) async {
        loads++;
        return loads == 1 ? http.Response('{}', 500) : pending.future;
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(app(JobsOverviewView(api: api, authorize: _auth)));
    await tester.pumpAndSettle();
    expect(key('jobs-stat-available'), findsNothing);
    await tester.tap(key('retry-jobs-overview'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(key('jobs-stat-available'), findsNothing);
    pending.complete(response(total: 23));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(key('jobs-stat-available')).data, '23');
  });
}
