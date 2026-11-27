import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/dashboard/screens/live_coaching_view.dart';
import 'package:josjob_fe/services/live_coaching_api.dart';
import 'live_coaching_api_test.dart' show coachingJson, profileJson;

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

  Future<void> showCoaching(
    WidgetTester tester,
    LiveCoachingApi api, {
    void Function(CoachingBooking)? join,
    bool admin = false,
    bool workspace = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LiveCoachingView(
              api: api,
              authorize: _authorize,
              onJoin: join,
              isAdmin: admin,
              initialWorkspace: workspace,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!workspace) {
      expect(find.byKey(const ValueKey('coach-workspace')), findsNothing);
    }
  }

  testWidgets(
    'books an independent free appointment even when video is unconfigured',
    (tester) async {
      var booked = false;
      final requests = <http.Request>[];
      final api = LiveCoachingApi(
        client: MockClient((r) async {
          requests.add(r);
          if (r.method == 'POST') {
            booked = true;
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
            jsonEncode({'data': coachingJson(booked: booked)}),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await showCoaching(tester, api);
      expect(
        find.byKey(const ValueKey('empty-coaching-bookings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('coaching-video-unavailable')),
        findsOneWidget,
      );
      final profile = find.byKey(const ValueKey('view-coach-coach-1'));
      await tester.ensureVisible(profile);
      await tester.tap(profile);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('book-slot-slot-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('coaching-booking-booking-1')),
        findsOneWidget,
      );
      expect(
        requests.any(
          (r) => r.url.path == '/api/coaching/bookings' && r.method == 'POST',
        ),
        isTrue,
      );
      expect(requests.any((r) => r.url.path.contains('/classes')), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('joins the booking room with the server role', (tester) async {
    final api = LiveCoachingApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': coachingJson(configured: true, booked: true, canJoin: true),
          }),
          200,
        ),
      ),
    );
    addTearDown(api.close);
    CoachingBooking? selected;
    await showCoaching(tester, api, join: (b) => selected = b);
    await tester.tap(find.byKey(const ValueKey('join-booking-booking-1')));
    expect(selected!.roomId, 'coaching:booking-1:one_on_one');
    expect(selected!.host, isFalse);
  });
  testWidgets(
    'mobile searches profile expertise and retries real API failures',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final api = LiveCoachingApi(
        client: MockClient((_) async {
          if (++calls == 1) {
            return http.Response('{"error":"unavailable"}', 503);
          }
          return http.Response(jsonEncode({'data': coachingJson()}), 200);
        }),
      );
      addTearDown(api.close);
      await showCoaching(tester, api);
      await tester.tap(find.byKey(const ValueKey('retry-coaching')));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('search-coaches'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Interviews');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('coach-profile-coach-1')),
        findsOneWidget,
      );
      await tester.enterText(search, 'absent');
      await tester.pumpAndSettle();
      expect(find.text('No coaches match your search.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'coach workspace saves a profile independently from course authoring',
    (tester) async {
      Map<String, dynamic>? submitted;
      final api = LiveCoachingApi(
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            submitted = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
            jsonEncode({'data': coachingJson(own: true)}),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await showCoaching(tester, api, workspace: true);
      await tester.tap(find.byKey(const ValueKey('coach-workspace')));
      await tester.pumpAndSettle();
      expect(find.text('Profile status: pending'), findsOneWidget);
      final save = find.byKey(const ValueKey('save-coach-profile'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(submitted!['session_minutes'], 30);
      expect(submitted!.containsKey('course_id'), isFalse);
      expect(submitted!.containsKey('status'), isFalse);
    },
  );
  testWidgets('admin explicitly approves coach publication', (tester) async {
    var approved = false;
    final api = LiveCoachingApi(
      client: MockClient((r) async {
        if (r.method == 'PATCH') {
          approved = true;
          return http.Response('{"ok":true}', 200);
        }
        if (r.url.path.endsWith('/admin/profiles')) {
          return http.Response(
            jsonEncode({
              'data': [profileJson(status: approved ? 'approved' : 'pending')],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': coachingJson()}), 200);
      }),
    );
    addTearDown(api.close);
    await showCoaching(tester, api, admin: true);
    await tester.tap(find.text('Review coach profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(approved, isTrue);
    expect(find.text('Suspend'), findsOneWidget);
  });
}
