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
import 'package:josjob_fe/jobs/jobs_page.dart';

import 'package:file_picker/file_picker.dart';
import 'package:josjob_fe/services/job_rankings_api.dart';

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

  testWidgets(
    'saved CV shows ready state without upload, consent or analysis requests',
    (tester) async {
      final api = JobRankingsApi(
        client: MockClient(
          (_) async => throw StateError(
            'No request is needed to restore saved metadata',
          ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CvJobRankings(
                api: api,
                authorize: _authorize,
                savedCvId: 'existing',
                savedCategories: const ['backend'],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your CV is ready'), findsOneWidget);
      expect(find.byKey(const ValueKey('cv-saved-ready')), findsOneWidget);
      expect(find.byKey(const ValueKey('upload-ranking-cv')), findsNothing);
      expect(find.byKey(const ValueKey('cv-processing-consent')), findsNothing);
      expect(find.textContaining('Analyze your CV once'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('change-ranking-cv')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cv-processing-consent')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('upload-ranking-cv')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('cancel-cv-replacement')));
      await tester.pumpAndSettle();
      expect(find.text('Your CV is ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading saved CV never flashes a first-time upload form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CvJobRankings(authorize: _authorize, checkingSavedCv: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('cv-state-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-ranking-cv')), findsNothing);
    expect(find.byKey(const ValueKey('cv-processing-consent')), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CvJobRankings(
            authorize: _authorize,
            savedCvId: 'restored',
            savedCategories: const ['design'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your CV is ready'), findsOneWidget);
  });

  testWidgets(
    'consent gates PDF upload and extracted skills lead to explained rankings',
    (tester) async {
      final requests = <String>[];
      Map<String, dynamic>? saved;
      final api = JobRankingsApi(
        client: MockClient((request) async {
          requests.add(request.url.path);
          final Map<String, dynamic> data;
          if (request.url.path.endsWith('/extractions')) {
            data = {'id': 'owned', 'status': 'queued'};
          } else if (request.url.path.endsWith('/extractions/owned')) {
            data = {
              'status': 'partial',
              'provider': 'keyword',
              'result': {
                'skills': [
                  {'name': 'Elixir'},
                ],
              },
              'warnings': [],
            };
          } else {
            data = {
              'provider': 'local',
              'semantic': false,
              'cv_id': 'saved-cv',
              'profile': {
                'categories': ['backend'],
              },
              'persisted': true,
              'jobs': [
                {
                  'job_id': 'best',
                  'match': 0.75,
                  'match_score': 0.8,
                  'job': {
                    'title': 'Backend Engineer',
                    'company': 'Test Company',
                    'location': 'Remote',
                  },
                  'explanation': 'One requirement is missing.',
                  'matched_skills': ['Elixir'],
                  'missing_skills': ['SQL'],
                },
              ],
            };
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CvJobRankings(
                api: api,
                authorize: _authorize,
                onProfileReady: (value) => saved = value,
                pickPdf: () async => PlatformFile(
                  name: 'cv.pdf',
                  size: 8,
                  bytes: Uint8List.fromList('%PDF-1.4'.codeUnits),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final upload = find.byKey(const ValueKey('upload-ranking-cv'));
      expect(tester.widget<FilledButton>(upload).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('cv-processing-consent')));
      await tester.pumpAndSettle();
      await tester.tap(upload);
      await tester.pumpAndSettle();
      expect(find.text('Elixir'), findsOneWidget);
      expect(find.textContaining('Part of your CV was read'), findsOneWidget);
      final rank = find.byKey(const ValueKey('rank-cv-jobs'));
      await tester.ensureVisible(rank);
      await tester.tap(rank);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ranked-job-best')), findsNothing);
      expect(find.byKey(const ValueKey('cv-saved-ready')), findsOneWidget);
      expect(find.text('Your CV is ready'), findsOneWidget);
      expect(find.textContaining('Your saved CV is available'), findsOneWidget);
      expect(saved?['cv_id'], 'saved-cv');
      expect(requests, [
        '/api/rag/cv/extractions',
        '/api/rag/cv/extractions/owned',
        '/api/rag/analyses',
      ]);
      expect(find.byKey(const ValueKey('rank-cv-jobs')), findsNothing);
      expect(find.byKey(const ValueKey('cv-processing-consent')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
