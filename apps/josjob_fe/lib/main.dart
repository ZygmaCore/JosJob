import 'package:flutter/material.dart';
import 'landing/landing_page_ascent.dart';
import 'auth/auth_page.dart';
import 'auth/org_pending_page.dart';
import 'onboarding/onboarding_page.dart';
import 'dashboard/dashboard_page.dart';
import 'dashboard/screens/live_coaching_view.dart';
import 'explore/explore_page.dart';
import 'quiz/quiz_page.dart';
import 'vod/vod_page.dart';
import 'vod/vod_document_upload_page.dart';
import 'documents/documents_page.dart';
import 'jobs/jobs_page.dart';
import 'invite/invite_accept_page.dart';
import 'admin/teacher_invitations_page.dart';
import 'teacher/teacher_dashboard_page.dart';
import 'bootstrap/bootstrap_page.dart';
import 'services/session.dart';
import 'services/auth_api.dart' show AccountType;
import 'services/sync/sync_engine.dart';
import 'services/ui_preferences.dart';
import 'applications/applications_view.dart';
import 'chat/chat_page.dart';
import 'shared/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Rehydrate a previously "remembered" session so a browser reload skips the
  // landing page and lands straight in the app.
  await Session.instance.restore();
  await AuthContinuation.restore();
  // A signed-out visitor never opens the outbox DB (the sync engine's flush is
  // a no-op until sign-in), so start the engine now and let them reach the
  // landing page instantly. A signed-in session opens the DB at startup, so
  // that path defers start() to AppBootstrap.onReady — after the wasm is warm.
  if (!Session.instance.isSignedIn) SyncEngine.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final _routeInformation = AppRouteInformationProvider();
  late final _router = AppRouterDelegate(
    routeFactory: _onGenerateRoute,
    builder: (context, child) => Session.instance.isSignedIn
        ? AppBootstrap(onReady: SyncEngine.instance.start, child: child)
        : child,
  );

  @override
  void dispose() {
    _router.dispose();
    _routeInformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JosJob',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      routerDelegate: _router,
      routeInformationParser: const AppRouteParser(),
      routeInformationProvider: _routeInformation,
      // The delegate gates Navigator content while keeping Router mounted so
      // browser history remains responsive during the SQLite startup splash.
    );
  }

  // Startup destination: landing when signed out; otherwise the role-specific
  // home ([_homeFor]).
  Widget _startScreen() {
    final session = Session.instance;
    if (!session.isSignedIn) return const JosjobLandingPage();
    return _homeFor(session);
  }

  // Role-adaptive home for a signed-in user:
  //   • superuser → Teacher Invitations admin (their reason to be here),
  //   • teacher   → Teacher workspace (documents),
  //   • org       → dashboard once approved, else the "request received" page,
  //   • otherwise → onboarding until the mandatory step is done, then dashboard.
  Widget _homeFor(Session session, {Uri? location}) {
    final user = session.user;
    if (user?.isSuperuser == true) return const TeacherInvitationsPage();
    if (user?.isTeacher == true) {
      return TeacherDashboardPage(firstName: user?.firstName);
    }
    if (user?.accountType == AccountType.organization) {
      return user?.approved == true
          ? _dashboard(user?.firstName, location)
          : const OrgPendingPage();
    }
    final onboarded = user?.mandatoryCompleted ?? false;
    return onboarded
        ? _dashboard(user?.firstName, location)
        : OnboardingFlow(firstName: user?.firstName);
  }

  Widget _dashboard(String? firstName, Uri? location) => DashboardPage(
    firstName: firstName,
    initialView: location?.queryParameters['view'] ?? 'learn',
    initialTab: location?.queryParameters['tab'] ?? 'overview',
    applicationScope: location?.queryParameters['scope'] ?? 'mine',
    applicationStatus: location?.queryParameters['status'] ?? '',
  );

  // Named-route table. Private so [_onGenerateRoute] is the ONLY entry point.
  static final Map<String, Widget Function()> _routes = {
    '/login': () => const LoginPage(),
    '/register': () => const RegisterPage(),
    '/onboarding': () => const OnboardingFlow(),
    '/dashboard': () => const DashboardPage(),
    '/coaching': () => const CoachingPage(),
    '/explore': () => const ExploreCoursePage(),
    '/quiz': () => const QuizPage(),
    '/vod': () => const VodPlayerPage(),
    '/vod/document': () => const VodDocumentUploadPage(),
    '/documents': () => const DocumentsPage(),
    '/jobs': () => const JobsPage(),
    '/admin/teacher-invitations': () => const TeacherInvitationsPage(),
  };

  // Auth pages a signed-in user has no reason to revisit.
  static const Set<String> _authRoutes = {'/login', '/register'};
  // Routes only a platform superuser may open.
  static const Set<String> _needsSuperuser = {'/admin/teacher-invitations'};
  // In-app destinations that additionally require a completed mandatory
  // onboarding step (mirrors the cold-start decision in [_startScreen]).
  static const Set<String> _needsOnboarding = {
    '/coaching',
    '/dashboard',
    '/explore',
    '/quiz',
    '/vod',
    '/vod/document',
    '/documents',
  };

  // Central auth guard for every named route. On web a signed-out visitor can
  // deep-link straight to a protected path (e.g. /dashboard); rather than
  // render it with no session, redirect based on the live [Session] state:
  //   • signed-out → a protected route   ⇒ landing page
  //   • signed-in  → /login or /register ⇒ into the app ([_startScreen])
  //   • signed-in but not onboarded → an in-app route ⇒ onboarding
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final session = Session.instance;
    final name = settings.name;

    // PUBLIC deep-link: teacher invitation accept (`/invite?token=…`). Reachable
    // signed-in or signed-out — the invitee typically has no session yet, and
    // accepting creates/links the account. Parsed from the full URL (query
    // string), which is why it's matched before the exact-name route table.
    final uri = Uri.parse(name ?? '/');
    if (uri.path == '/') return _route(_startScreen(), '/');
    if (uri.path == '/welcome') {
      return _route(const JosjobLandingPage(), '/welcome');
    }
    if (uri.path == '/invite') {
      return _route(
        InviteAcceptPage(token: uri.queryParameters['token']),
        '/invite',
      );
    }

    final signedIn = session.isSignedIn;
    final onboarded = session.user?.mandatoryCompleted ?? false;

    Widget Function()? builder = _routes[uri.path];
    final parts = uri.pathSegments;
    final jobDetail = parts.length == 2 && parts.first == 'jobs';
    if (jobDetail) {
      builder = () => JobDetailsPage(
        jobId: parts[1],
        apply: uri.queryParameters['apply'] == '1',
      );
    }
    if (parts.length == 2 && parts.first == 'applications') {
      builder = () => ApplicationDetailPage(applicationId: parts[1]);
    }
    if (uri.path == '/applications') {
      builder = () => ApplicationsPage(
        hiring: uri.queryParameters['scope'] == 'hiring',
        jobId: uri.queryParameters['job_id'],
      );
    }
    if (parts.length == 3 &&
        parts.first == 'chats' &&
        {'application', 'coaching'}.contains(parts[1])) {
      builder = () => ChatPage(
        kind: parts[1],
        contextId: parts[2],
        title: parts[1] == 'application'
            ? 'Hiring conversation'
            : 'Coaching conversation',
      );
    }
    // Unknown route → landing.
    if (builder == null) return _route(const JosjobLandingPage(), '/');

    // Published vacancies are available before login and onboarding.
    if (jobDetail) return _route(builder(), uri.toString());
    if (uri.path == '/jobs') {
      return _route(
        JobsPage(
          initialQuery: settings.arguments is String
              ? settings.arguments as String
              : uri.queryParameters['q'] ?? '',
        ),
        name!,
      );
    }

    // Auth pages: send an already-signed-in user into the app instead.
    if (_authRoutes.contains(uri.path)) {
      return signedIn ? _route(_startScreen(), '/') : _route(builder(), name!);
    }

    // Protected from here on: no session ⇒ back to the landing page.
    if (!signedIn) {
      AuthContinuation.remember(uri.toString());
      return _route(const LoginPage(), '/login');
    }

    // Superuser-only routes: bounce everyone else to their own home.
    if (_needsSuperuser.contains(uri.path) &&
        session.user?.isSuperuser != true) {
      return _route(_homeFor(session), '/');
    }

    // The generic dashboard route resolves to the role-specific home
    // (superuser → invitations, teacher → workspace, org → dashboard/pending…).
    if (uri.path == '/dashboard') {
      if (!onboarded &&
          session.user?.accountType != AccountType.organization &&
          session.user?.isTeacher != true &&
          session.user?.isSuperuser != true) {
        AuthContinuation.remember(uri.toString());
      }
      return _route(_homeFor(session, location: uri), uri.toString());
    }

    // Corporation / Institution accounts are pending review — they never reach
    // onboarding or any in-app destination, only the "request received" screen.
    if (session.user?.accountType == AccountType.organization) {
      // Un-provisioned org accounts stay on the pending page; approved ones
      // skip onboarding and reach the requested in-app route directly.
      if (session.user?.approved != true) {
        return _route(const OrgPendingPage(), '/pending');
      }
      return _route(builder(), name!);
    }
    // Not-yet-onboarded ⇒ finish onboarding before any in-app destination.
    if (!onboarded && _needsOnboarding.contains(uri.path)) {
      AuthContinuation.remember(uri.toString());
      return _route(
        OnboardingFlow(firstName: session.user?.firstName),
        '/onboarding',
      );
    }
    return _route(builder(), name!);
  }

  // Wraps a page in a MaterialPageRoute, tagging it with [name] so the web URL
  // bar reflects the destination actually shown after any redirect.
  MaterialPageRoute<dynamic> _route(Widget page, String name) =>
      MaterialPageRoute(
        builder: (_) => page,
        settings: RouteSettings(name: name),
      );
}
