import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Web-only GIS-rendered button. This app is web-only, so importing web_only.dart
// directly is safe (a multi-platform app would guard it behind a conditional
// import to avoid compiling it on mobile).
import 'package:google_sign_in_web/web_only.dart' as gis;

import '../../services/api_config.dart';
import '../../theme/app_theme.dart' show AppColors;

// =========================================================================
// JosJob — Google sign-in button (web)
//
// google_sign_in v7 removed programmatic web sign-in: on the web the ONLY way
// to obtain an id_token is a click on Google's own GIS-rendered button. This
// widget renders that button and hands the resulting id_token to [onIdToken]
// (the auth pages POST it to /api/auth/google via Session). It is a standalone
// library — not a `part` of auth_page.dart — because it needs its own
// google_sign_in imports, which `part` files can't have.
// =========================================================================

/// Initializes the GoogleSignIn singleton exactly once (v7 requires a single
/// `initialize()` call — repeating it is undefined behavior). Idempotent, so it
/// is safe to call from every button that mounts.
Future<void>? _initFuture;
Future<void> ensureGoogleSignInInitialized() => _initFuture ??= GoogleSignIn
    .instance
    .initialize(clientId: ApiConfig.googleClientId)
    .catchError((Object error) {
      // Don't cache a failed init forever — let a later remount retry.
      _initFuture = null;
      throw error;
    });

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, required this.onIdToken, this.onError});

  /// Called with the Google id_token after a successful GIS sign-in.
  final Future<void> Function(String idToken) onIdToken;

  /// Called if initialization or the GIS flow errors.
  final void Function(Object error)? onError;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _sub = GoogleSignIn.instance.authenticationEvents.listen(
      _onEvent,
      onError: (Object e) => widget.onError?.call(e),
    );
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await ensureGoogleSignInInitialized();
      // NOTE: deliberately NOT calling attemptLightweightAuthentication() here.
      // It silently re-authenticates and emits a sign-in event without a click,
      // which would auto-trigger navigation on every button remount. Session
      // persistence is handled by Session.restore(); Google sign-in should only
      // happen on an explicit click of the GIS button below.
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _failed = true);
      widget.onError?.call(e);
    }
  }

  Future<void> _onEvent(GoogleSignInAuthenticationEvent event) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    // `authentication` is a synchronous getter in v7; idToken is nullable.
    final idToken = user?.authentication.idToken;
    if (idToken == null || idToken.isEmpty) return;
    await widget.onIdToken(idToken);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _fallback();
    if (!_ready) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
          ),
        ),
      );
    }
    // GIS only ever renders Google's own button; GSIButtonConfiguration is the
    // only styling Google permits. Match the app's white social-pill look as
    // closely as allowed: outline (white bg) + pill shape + large.
    return SizedBox(
      height: 50,
      child: Center(
        child: gis.renderButton(
          configuration: gis.GSIButtonConfiguration(
            theme: gis.GSIButtonTheme.outline,
            size: gis.GSIButtonSize.large,
            shape: gis.GSIButtonShape.pill,
            text: gis.GSIButtonText.continueWith,
            logoAlignment: gis.GSIButtonLogoAlignment.left,
            minimumWidth: 320,
          ),
        ),
      ),
    );
  }

  Widget _fallback() => SizedBox(
    height: 50,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Center(
        child: Text(
          'Google sign-in unavailable',
          style: TextStyle(color: AppColors.body, fontSize: 13),
        ),
      ),
    ),
  );
}
