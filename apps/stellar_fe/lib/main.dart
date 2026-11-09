import 'package:flutter/material.dart';
import 'landing/landing_page_ascent.dart';
import 'auth/auth_page.dart';
import 'auth/org_pending_page.dart';
import 'onboarding/onboarding_page.dart';
import 'dashboard/dashboard_page.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Rehydrate a previously "remembered" session so a browser reload skips the
  // landing page and lands straight in the app.
  await Session.instance.restore();
  // A signed-out visitor never opens the outbox DB (the sync engine's flush is
  // a no-op until sign-in), so start the engine now and let them reach the
  // landing page instantly. A signed-in session opens the DB at startup, so
  // that path defers start() to AppBootstrap.onReady — after the wasm is warm.
  if (!Session.instance.isSignedIn) SyncEngine.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atveti Stellar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandBlue,
          primary: AppColors.brandBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
      ),
      home: _startScreen(),
      // Every named push/deep-link goes through the guard — there is no
      // ungated `routes:` map that could bypass the auth check.
      onGenerateRoute: _onGenerateRoute,
      // Gate the WHOLE app — not just the root route — behind the sqlite3.wasm
      // prefetch splash on a signed-in startup, so the download progress shows
      // on every load/reload. A reload straight to e.g. /#/dashboard resolves
      // through onGenerateRoute and never touches `home`, so gating `home`
      // alone would skip the splash there; wrapping the Navigator here covers
      // it once for whatever the initial route is. Only a signed-in startup
      // opens the outbox DB (the sync engine flushes it on launch), so this
      // starts the engine once the wasm is warm; signed-out visitors get the
      // app immediately, downloading nothing.
      builder: (context, child) {
        if (!Session.instance.isSignedIn) return child!;
        return AppBootstrap(onReady: SyncEngine.instance.start, child: child!);
      },
    );
  }

  // Startup destination: landing when signed out; otherwise the role-specific
  // home ([_homeFor]).
  Widget _startScreen() {
    final session = Session.instance;
    if (!session.isSignedIn) return const StellarLandingPage();
    return _homeFor(session);
  }

  // Role-adaptive home for a signed-in user:
  //   • superuser → Teacher Invitations admin (their reason to be here),
  //   • teacher   → Teacher workspace (documents),
  //   • org       → dashboard once approved, else the "request received" page,
  //   • otherwise → onboarding until the mandatory step is done, then dashboard.
  Widget _homeFor(Session session) {
    final user = session.user;
    if (user?.isSuperuser == true) return const TeacherInvitationsPage();
    if (user?.isTeacher == true) {
      return TeacherDashboardPage(firstName: user?.firstName);
    }
    if (user?.accountType == AccountType.organization) {
      return user?.approved == true
          ? DashboardPage(firstName: user?.firstName)
          : const OrgPendingPage();
    }
    final onboarded = user?.mandatoryCompleted ?? false;
    return onboarded
        ? DashboardPage(firstName: user?.firstName)
        : OnboardingFlow(firstName: user?.firstName);
  }

  // Named-route table. Private so [_onGenerateRoute] is the ONLY entry point.
  static final Map<String, Widget Function()> _routes = {
    '/login': () => const LoginPage(),
    '/register': () => const RegisterPage(),
    '/onboarding': () => const OnboardingFlow(),
    '/dashboard': () => const DashboardPage(),
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
    '/dashboard',
    '/explore',
    '/quiz',
    '/vod',
    '/vod/document',
    '/documents',
    '/jobs',
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
    if (uri.path == '/invite') {
      return _route(
        InviteAcceptPage(token: uri.queryParameters['token']),
        '/invite',
      );
    }

    final signedIn = session.isSignedIn;
    final onboarded = session.user?.mandatoryCompleted ?? false;

    final builder = _routes[name];
    // Unknown route → landing.
    if (builder == null) return _route(const StellarLandingPage(), '/');

    // Auth pages: send an already-signed-in user into the app instead.
    if (_authRoutes.contains(name)) {
      return signedIn ? _route(_startScreen(), '/') : _route(builder(), name!);
    }

    // Protected from here on: no session ⇒ back to the landing page.
    if (!signedIn) return _route(const StellarLandingPage(), '/');

    // Superuser-only routes: bounce everyone else to their own home.
    if (_needsSuperuser.contains(name) && session.user?.isSuperuser != true) {
      return _route(_homeFor(session), '/');
    }

    // The generic dashboard route resolves to the role-specific home
    // (superuser → invitations, teacher → workspace, org → dashboard/pending…).
    if (name == '/dashboard') {
      return _route(_homeFor(session), '/dashboard');
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
    if (!onboarded && _needsOnboarding.contains(name)) {
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
