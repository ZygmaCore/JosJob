import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:josjob_fe/shared/app_router.dart';

void main() {
  testWidgets('route reports preserve reserved characters in search values', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
    final provider = AppRouteInformationProvider(
      initial: RouteInformation(uri: Uri.parse('/welcome')),
    );
    addTearDown(provider.dispose);
    const query = 'Frontend & UX + 100% #1';
    final uri = Uri(path: '/jobs', queryParameters: {'q': query});
    provider.routerReportsNewRouteInformation(RouteInformation(uri: uri));
    await tester.pump();
    final report = calls.lastWhere(
      (call) => call.method == 'routeInformationUpdated',
    );
    final reported = report.arguments[kIsWeb ? 'location' : 'uri'] as String;
    expect(Uri.parse(reported).queryParameters['q'], query);
    expect(provider.value.uri.queryParameters['q'], query);
    expect(report.arguments['replace'], isFalse);
  });

  testWidgets(
    'browser replay updates the route without adding a new history entry',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
      final provider = AppRouteInformationProvider(
        initial: RouteInformation(uri: Uri.parse('/welcome')),
      );
      addTearDown(provider.dispose);
      var changes = 0;
      void changed() {
        changes++;
      }

      provider.addListener(changed);
      final replay = RouteInformation(
        uri: Uri(path: '/jobs', queryParameters: {'q': 'C# & SQL'}),
      );
      await provider.didPushRouteInformation(replay);
      expect(changes, 1);
      expect(provider.value.uri.queryParameters['q'], 'C# & SQL');
      provider.routerReportsNewRouteInformation(replay);
      await tester.pump();
      expect(
        calls
            .lastWhere((call) => call.method == 'routeInformationUpdated')
            .arguments['replace'],
        isTrue,
      );
      provider.removeListener(changed);
    },
  );
  testWidgets('browser history can change while startup content is gated', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    final provider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: Uri.parse('/jobs/job-1')),
    );
    final delegate = AppRouterDelegate(
      routeFactory: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text(settings.name!)),
      ),
      builder: (_, child) => ValueListenableBuilder<bool>(
        valueListenable: ready,
        builder: (_, value, _) => value ? child : const SizedBox(),
      ),
    );
    addTearDown(ready.dispose);
    addTearDown(provider.dispose);
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: const AppRouteParser(),
        routeInformationProvider: provider,
      ),
    );
    await provider.didPushRouteInformation(
      RouteInformation(uri: Uri.parse('/dashboard?view=jobs&tab=applications')),
    );
    await tester.pumpAndSettle();
    ready.value = true;
    await tester.pumpAndSettle();
    expect(find.text('/dashboard?view=jobs&tab=applications'), findsOneWidget);
    expect(
      provider.value.uri.toString(),
      '/dashboard?view=jobs&tab=applications',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('named routes and browser replay preserve the full destination', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      routeFactory: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Scaffold(
          body: Text(settings.name!, key: const ValueKey('location')),
        ),
      ),
    );
    addTearDown(delegate.dispose);
    await delegate.setNewRoutePath(
      '/dashboard?view=jobs&tab=applications&scope=hiring',
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: const AppRouteParser(),
      ),
    );
    await tester.pumpAndSettle();
    delegate.navigatorKey.currentState!.pushNamed('/jobs/job-1');
    await tester.pumpAndSettle();
    expect(delegate.currentConfiguration, '/jobs/job-1');
    await delegate.setNewRoutePath(
      '/dashboard?view=jobs&tab=applications&scope=hiring',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('location'))).data,
      '/dashboard?view=jobs&tab=applications&scope=hiring',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an auth redirect reports the destination actually displayed', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      routeFactory: (_) => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => const Scaffold(body: Text('Sign in')),
      ),
    );
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: const AppRouteParser(),
      ),
    );
    await tester.pumpAndSettle();
    expect(delegate.currentConfiguration, '/login');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a cold deep link never reports an intermediate home route', (
    tester,
  ) async {
    const location = '/dashboard?view=jobs&tab=applications&scope=hiring';
    final provider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: Uri.parse(location)),
    );
    final delegate = AppRouterDelegate(
      routeFactory: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text(settings.name!)),
      ),
    );
    addTearDown(provider.dispose);
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: const AppRouteParser(),
        routeInformationProvider: provider,
      ),
    );
    expect(delegate.currentConfiguration, location);
    await tester.pumpAndSettle();
    expect(find.text(location), findsOneWidget);
    expect(provider.value.uri.toString(), location);
    await provider.didPushRouteInformation(
      RouteInformation(uri: Uri.parse('/jobs/job-1')),
    );
    await tester.pumpAndSettle();
    expect(delegate.currentConfiguration, '/jobs/job-1');
    expect(provider.value.uri.toString(), '/jobs/job-1');
    expect(find.text('/jobs/job-1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
