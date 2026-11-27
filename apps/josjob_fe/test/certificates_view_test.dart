import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/dashboard/screens/certificates_view.dart';
import 'package:josjob_fe/services/certificates_api.dart';
import 'certificates_api_test.dart' show certificateJson;

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
  Future<void> show(
    WidgetTester tester,
    CertificatesApi api, {
    void Function(String)? open,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CertificatesView(
              api: api,
              authorize: _authorize,
              onOpenLink: open,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-certificate')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('additional-certificates-tab')));
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('adds, edits, opens and deletes the persisted certificate', (
    tester,
  ) async {
    final records = <Map<String, dynamic>>[];
    final writes = <String>[];
    String? opened;
    final api = CertificatesApi(
      client: MockClient((r) async {
        if (r.method == 'POST') {
          records.add({
            ...certificateJson(),
            ...jsonDecode(r.body) as Map<String, dynamic>,
          });
          writes.add('POST');
        }
        if (r.method == 'PATCH') {
          records[0].addAll(jsonDecode(r.body) as Map<String, dynamic>);
          writes.add('PATCH');
        }
        if (r.method == 'DELETE') {
          records.clear();
          writes.add('DELETE');
        }
        return http.Response(
          jsonEncode(r.method == 'GET' ? {'data': records} : {'ok': true}),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await show(tester, api, open: (url) => opened = url);
    expect(key('empty-certificates'), findsOneWidget);
    expect(find.text('Workplace Safety Level 1'), findsNothing);
    expect(find.text('Target certificates'), findsNothing);
    await tester.tap(key('add-certificate'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Actual first aid',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Actual issuer');
    await tester.enterText(
      find.byType(TextFormField).at(5),
      'https://example.com/proof',
    );
    await tester.tap(key('save-certificate'));
    await tester.pumpAndSettle();
    expect(key('certificate-cert-1'), findsOneWidget);
    expect(find.text('Actual first aid'), findsOneWidget);
    await tester.ensureVisible(find.text('Open credential'));
    await tester.tap(find.text('Open credential'));
    expect(opened, 'https://example.com/proof');
    await tester.tap(key('edit-certificate-cert-1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Updated first aid',
    );
    await tester.tap(key('save-certificate'));
    await tester.pumpAndSettle();
    expect(find.text('Updated first aid'), findsOneWidget);
    await tester.ensureVisible(key('delete-certificate-cert-1'));
    await tester.tap(key('delete-certificate-cert-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete certificate'));
    await tester.pumpAndSettle();
    expect(key('empty-certificates'), findsOneWidget);
    expect(writes, ['POST', 'PATCH', 'DELETE']);
  });

  testWidgets(
    'shows actual onboarding records and expiry on mobile without verification claims',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = CertificatesApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                certificateJson(
                  id: 'onboarding-0',
                  title: 'Onboarding qualification',
                  source: 'onboarding',
                ),
                {
                  ...certificateJson(),
                  'expired': true,
                  'expires_on': '2025-01-01',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(api.close);
      await show(tester, api);
      expect(find.text('Onboarding qualification'), findsOneWidget);
      expect(find.text('Recorded period: 2024-06 – 2025'), findsOneWidget);
      expect(key('edit-certificate-onboarding-0'), findsNothing);
      expect(key('delete-certificate-onboarding-0'), findsNothing);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Verified'), findsNothing);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('retries loading and keeps entered data after a save error', (
    tester,
  ) async {
    var loads = 0, saves = 0;
    final api = CertificatesApi(
      client: MockClient((r) async {
        if (r.method == 'GET') {
          loads++;
          return loads == 1
              ? http.Response('{}', 500)
              : http.Response('{"data":[]}', 200);
        }
        saves++;
        return http.Response('{}', 422);
      }),
    );
    addTearDown(api.close);
    await show(tester, api);
    expect(find.text('0 certificates saved'), findsNothing);
    await tester.tap(key('retry-certificates'));
    await tester.pumpAndSettle();
    expect(key('empty-certificates'), findsOneWidget);
    await tester.tap(key('add-certificate'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'My qualification',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Training provider',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '2025-02-30');
    await tester.tap(key('save-certificate'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('Use YYYY-MM-DD'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '2025-01-01');
    await tester.tap(key('save-certificate'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(key('certificate-save-error'), findsOneWidget);
    expect(find.text('My qualification'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
