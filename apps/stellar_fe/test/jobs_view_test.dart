import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The package exposes these hooks specifically for deterministic font tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_fe/jobs/jobs_page.dart';
import 'package:stellar_fe/services/jobs_api.dart';

import 'jobs_api_test.dart' show jobJson;

class _TestFonts implements AssetManifest {
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

Future<T> _authorize<T>(Future<T> Function(String) call) => call('test-token');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Reuse a valid bundled test font, avoiding network or device-file access.
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

  Future<void> showBoard(WidgetTester tester, JobsApi api) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobsView(api: api, authorize: _authorize),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('searches through the API and opens fresh job details', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = JobsApi(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('job-1')) {
          return http.Response(
            jsonEncode({'data': jobJson()..['can_manage'] = false}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': [jobJson()],
            'organizations': [],
            'meta': {'page': 1, 'total': 1, 'total_pages': 1},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await showBoard(tester, api);
    expect(find.byKey(const ValueKey('job-job-1')), findsOneWidget);
    expect(find.textContaining('% match'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('jobs-search')), 'SQL');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['q'], 'SQL');
    await tester.ensureVisible(find.byKey(const ValueKey('job-job-1')));
    await tester.tap(find.byKey(const ValueKey('job-job-1')));
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/jobs/job-1');
    expect(find.byKey(const ValueKey('job-detail')), findsOneWidget);
    expect(find.text('Apply now'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'employer creates a draft and confirms deletion through the API',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var exists = false;
      final writes = <http.Request>[];
      final api = JobsApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          final job = jobJson()..['status'] = 'draft';
          if (request.method == 'POST') {
            writes.add(request);
            exists = true;
            return http.Response(jsonEncode({'data': job}), 201);
          }
          if (request.method == 'DELETE') {
            writes.add(request);
            exists = false;
            return http.Response('', 204);
          }
          if (request.url.path.endsWith('job-1')) {
            return http.Response(jsonEncode({'data': job}), 200);
          }
          return http.Response(
            jsonEncode({
              'data': exists ? [job] : [],
              'organizations': [
                {
                  'id': 'org-1',
                  'name': 'Studio',
                  'can_post': true,
                  'can_manage': true,
                },
              ],
              'meta': {
                'page': 1,
                'total': exists ? 1 : 0,
                'total_pages': exists ? 1 : 0,
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await showBoard(tester, api);
      await tester.tap(find.byKey(const ValueKey('post-job')));
      await tester.pumpAndSettle();
      for (final field in {
        'title': 'Junior developer',
        'location': 'Bandung',
        'industry': 'Technology',
        'description': 'Build useful software.',
      }.entries) {
        final input = find.byKey(ValueKey('job-field-${field.key}'));
        await tester.ensureVisible(input);
        await tester.enterText(input, field.value);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const ValueKey('save-job')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-job')));
      await tester.pumpAndSettle();
      expect(jsonDecode(writes.single.body)['status'], 'draft');
      final card = find.byKey(const ValueKey('job-job-1'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('delete-job')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-job')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(writes.map((r) => r.method), ['POST', 'DELETE']);
      expect(find.byKey(const ValueKey('jobs-empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows retry and honest empty states', (tester) async {
    var failing = true;
    final api = JobsApi(
      baseUrl: 'http://test',
      client: MockClient((_) async {
        if (failing) return http.Response('{}', 500);
        return http.Response(
          jsonEncode({
            'data': [],
            'organizations': [],
            'meta': {'page': 1, 'total': 0, 'total_pages': 0},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await showBoard(tester, api);
    expect(find.byKey(const ValueKey('jobs-error')), findsOneWidget);
    failing = false;
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jobs-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
