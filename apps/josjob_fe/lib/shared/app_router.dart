import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Reports canonical encoded paths. The web engine's `uri` channel currently
/// decodes reserved query characters; its supported `location` channel keeps
/// '&', '#', '+' and '%' inside search values intact in browser history.
class AppRouteInformationProvider extends RouteInformationProvider
    with WidgetsBindingObserver, ChangeNotifier {
  AppRouteInformationProvider({RouteInformation? initial})
    : _value =
          initial ??
          RouteInformation(
            uri: Uri.parse(
              WidgetsBinding.instance.platformDispatcher.defaultRouteName,
            ),
          ) {
    _inEngine = _value;
  }
  RouteInformation _value;
  late RouteInformation _inEngine;
  @override
  RouteInformation get value => _value;
  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    final replace =
        type == RouteInformationReportingType.neglect ||
        (type == RouteInformationReportingType.none &&
            routeInformation.uri == _inEngine.uri);
    SystemNavigator.selectMultiEntryHistory();
    if (kIsWeb) {
      SystemChannels.navigation.invokeMethod<void>('routeInformationUpdated', {
        'location': routeInformation.uri.toString(),
        'state': routeInformation.state,
        'replace': replace,
      });
    } else {
      SystemNavigator.routeInformationUpdated(
        uri: routeInformation.uri,
        state: routeInformation.state,
        replace: replace,
      );
    }
    _value = routeInformation;
    _inEngine = routeInformation;
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    _inEngine = routeInformation;
    if (_value.uri != routeInformation.uri ||
        _value.state != routeInformation.state) {
      _value = routeInformation;
      notifyListeners();
    }
    return true;
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) WidgetsBinding.instance.addObserver(this);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Keeps imperative feature navigation while Router owns browser history.
/// A reload creates only the requested page; Back/Forward replay its full URI.
class AppRouteParser extends RouteInformationParser<String> {
  const AppRouteParser();
  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(routeInformation.uri.toString());
  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri.parse(configuration));
}

class AppRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  final RouteFactory routeFactory;
  final Widget Function(BuildContext, Widget)? builder;
  AppRouterDelegate({required this.routeFactory, this.builder});
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String _location =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  bool _disposed = false;
  late final _observer = _LocationObserver((name) {
    if (name == null || name == _location) return;
    _location = name;
    // Redirects can be resolved while Navigator builds its initial page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  });
  @override
  String get currentConfiguration => _location;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    if (configuration == _location) return;
    _location = configuration;
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      configuration,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator(
      key: navigatorKey,
      initialRoute: _location,
      onGenerateInitialRoutes: (_, name) => [
        routeFactory(RouteSettings(name: name))!,
      ],
      onGenerateRoute: routeFactory,
      observers: [_observer],
    );
    return builder?.call(context, navigator) ?? navigator;
  }
}

class _LocationObserver extends NavigatorObserver {
  final ValueChanged<String?> onLocation;
  _LocationObserver(this.onLocation);
  @override
  void didChangeTop(
    Route<dynamic> topRoute,
    Route<dynamic>? previousTopRoute,
  ) => onLocation(topRoute.settings.name);
}
