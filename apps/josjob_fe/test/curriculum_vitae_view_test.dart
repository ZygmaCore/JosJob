import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/dashboard/screens/curriculum_vitae_view.dart';
import 'package:josjob_fe/services/curriculum_vitae_api.dart';
import 'curriculum_vitae_api_test.dart' show cvJson;

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
  http.Response response(Map<String, dynamic> data) => http.Response(
    jsonEncode({'data': data}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Future<void> show(WidgetTester tester, CurriculumVitaeView view) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: view)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders saved identity and background, certificates and precise dates without samples',
    (tester) async {
      var loads = 0, managed = false;
      final api = CurriculumVitaeApi(
        client: MockClient((_) async {
          loads++;
          return response(cvJson());
        }),
      );
      addTearDown(api.close);
      await show(
        tester,
        CurriculumVitaeView(
          api: api,
          authorize: _auth,
          onManageCertificates: () async {
            managed = true;
          },
        ),
      );
      expect(find.text('Actual Candidate'), findsOneWidget);
      expect(find.text('Actual employer'), findsOneWidget);
      expect(find.text('Actual university'), findsOneWidget);
      expect(find.text('From 2021-04'), findsOneWidget);
      expect(find.text('2017 – 2021-03'), findsOneWidget);
      expect(find.text('Actual certificate'), findsOneWidget);
      expect(find.text('Jordan Blake'), findsNothing);
      expect(find.text('82%'), findsNothing);
      expect(find.text('Certifications verified'), findsNothing);
      expect(key('open-cv-pdf'), findsNothing);
      await tester.ensureVisible(key('manage-cv-certificates'));
      await tester.tap(key('manage-cv-certificates'));
      await tester.pumpAndSettle();
      expect(managed, true);
      expect(loads, 2);
    },
  );

  testWidgets(
    'edits CV fields, selects an actual owned PDF, opens it and detaches it',
    (tester) async {
      var headline = 'Actual headline',
          summary = 'Actual professional summary',
          attached = false;
      String? opened;
      final writes = <Map<String, dynamic>>[];
      final api = CurriculumVitaeApi(
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            final attrs = jsonDecode(r.body) as Map<String, dynamic>;
            writes.add(attrs);
            if (attrs.containsKey('headline')) {
              headline = attrs['headline'] as String;
            }
            if (attrs.containsKey('summary')) {
              summary = attrs['summary'] as String;
            }
            if (attrs.containsKey('resume_document_id')) {
              attached = attrs['resume_document_id'] != null;
            }
          }
          return response(
            cvJson(headline: headline, summary: summary, attached: attached),
          );
        }),
      );
      addTearDown(api.close);
      await show(
        tester,
        CurriculumVitaeView(
          api: api,
          authorize: _auth,
          onOpenLink: (url) => opened = url,
        ),
      );
      await tester.tap(key('edit-cv'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Updated headline',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Updated summary',
      );
      await tester.tap(key('cv-document-select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actual resume.pdf').last);
      await tester.pumpAndSettle();
      await tester.tap(key('save-cv'));
      await tester.pumpAndSettle();
      expect(find.text('Updated headline'), findsOneWidget);
      expect(find.text('Updated summary'), findsOneWidget);
      expect(writes.single['resume_document_id'], 'pdf-1');
      await tester.ensureVisible(key('open-cv-pdf'));
      await tester.tap(key('open-cv-pdf'));
      expect(opened, 'https://example.com/resume.pdf');
      await tester.tap(key('detach-cv-pdf'));
      await tester.pumpAndSettle();
      expect(key('open-cv-pdf'), findsNothing);
      expect(find.text('Updated headline'), findsOneWidget);
      expect(writes.last, {'resume_document_id': null});
    },
  );

  testWidgets(
    'mobile empty CVs show genuine empty states and no fabricated PDF or history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = cvJson(empty: true);
      (data['identity'] as Map)['email'] =
          'a.very.long.actual.email.address.for.mobile@example.com';
      final api = CurriculumVitaeApi(
        client: MockClient((_) async => response(data)),
      );
      addTearDown(api.close);
      await show(tester, CurriculumVitaeView(api: api, authorize: _auth));
      expect(find.text('No work experience added yet.'), findsOneWidget);
      expect(find.text('No education added yet.'), findsOneWidget);
      expect(find.text('No skills added yet.'), findsOneWidget);
      expect(find.text('No certificates saved yet.'), findsOneWidget);
      expect(find.text('No resume PDF attached'), findsOneWidget);
      expect(key('open-cv-pdf'), findsNothing);
      expect(tester.takeException(), null);
      await tester.tap(key('edit-cv'));
      await tester.pumpAndSettle();
      expect(
        find.text('No saved PDF documents are available for your account.'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'retries loading and preserves editor input after a failed save',
    (tester) async {
      var loads = 0;
      final api = CurriculumVitaeApi(
        client: MockClient((r) async {
          if (r.method == 'PATCH') return http.Response('{}', 422);
          loads++;
          return loads == 1 ? http.Response('{}', 500) : response(cvJson());
        }),
      );
      addTearDown(api.close);
      await show(tester, CurriculumVitaeView(api: api, authorize: _auth));
      await tester.tap(key('retry-cv'));
      await tester.pumpAndSettle();
      expect(find.text('Actual Candidate'), findsOneWidget);
      await tester.tap(key('edit-cv'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Keep this draft',
      );
      await tester.tap(key('save-cv'));
      await tester.pumpAndSettle();
      expect(key('cv-save-error'), findsOneWidget);
      expect(find.text('Keep this draft'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
