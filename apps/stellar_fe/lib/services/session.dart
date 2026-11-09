import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'auth_api.dart';
import 'sync/sync_engine.dart';
import 'token_store.dart';

// =========================================================================
// ATVETI STELLAR — Session
//
// App-wide auth state. A single [Session.instance] holds the signed-in user
// and tokens, coordinates the [AuthApi] with [TokenStore], and notifies
// listeners on change. UI calls the high-level methods (register/login/
// signInWithGoogle/signOut); the Google *id_token* is obtained by the UI
// (see auth/widgets/google_auth.dart) and handed to [signInWithGoogle].
// =========================================================================
class Session extends ChangeNotifier {
  Session._();

  static final Session instance = Session._();

  final AuthApi _api = AuthApi();
  final TokenStore _store = TokenStore();

  AuthUser? _user;
  String? _token;
  String? _refreshToken;
  bool _persistSession = true;

  AuthUser? get user => _user;
  String? get accessToken => _token;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  /// Register with email + password. [accountType] selects Personal vs
  /// Corporation/Institution; the backend rejects free-provider emails for
  /// organization accounts. [phone], [address] and [birthdate] (ISO yyyy-MM-dd)
  /// are optional profile details persisted on the account. Throws
  /// [AuthException] on failure.
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required AccountType accountType,
    String? phone,
    String? address,
    String? birthdate,
  }) async {
    final session = await _api.register(
      fullName: fullName,
      email: email,
      password: password,
      accountType: accountType,
      phone: phone,
      address: address,
      birthdate: birthdate,
    );
    await _apply(session);
    return session.user;
  }

  /// Log in with email + password. Throws [AuthException] on failure.
  Future<AuthUser> login({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final session = await _api.login(email: email, password: password);
    await _apply(session, persist: remember);
    return session.user;
  }

  /// Exchange a Google *id_token* for a Stellar session. Returns the full
  /// session so callers can branch on [AuthSession.isNewUser]. Throws
  /// [AuthException] on failure.
  Future<AuthSession> signInWithGoogle(String idToken) async {
    final session = await _api.google(idToken);
    await _apply(session);
    return session;
  }

  /// Establish a session from an [AuthSession] obtained outside the standard
  /// auth calls (e.g. accepting a teacher invitation, which creates the account
  /// and returns tokens like register does). Persists like a normal sign-in.
  Future<void> signInWithSession(AuthSession session) => _apply(session);

  /// Rehydrate a previously stored session (e.g. on app start). Returns whether
  /// a signed-in session was restored.
  Future<bool> restore() async {
    _token = await _store.readToken();
    _refreshToken = await _store.readRefreshToken();
    _user = await _store.readUser();
    // A restored access token past its 1-hour life would 401 on the first
    // authenticated call — which used to strand users on onboarding (the
    // mandatory-step update silently failed, so it never persisted). Rotate an
    // expired token up front; refresh also returns the authoritative user, so a
    // reload agrees with a fresh login. Sign out if the refresh token is gone.
    final token = _token;
    if (isSignedIn && (token == null || _isExpired(token))) {
      final rt = _refreshToken;
      if (rt != null && rt.isNotEmpty) {
        await refresh();
      } else {
        await signOut();
      }
    }
    notifyListeners();
    return isSignedIn;
  }

  Future<bool>? _refreshInFlight;

  /// Rotate the refresh token for a fresh pair. Signs out if refresh fails.
  /// Single-flight: concurrent callers (e.g. several calls that 401 at once)
  /// share one in-flight rotation instead of each spending the refresh token.
  Future<bool> refresh() => _refreshInFlight ??= _refreshOnce().whenComplete(
    () => _refreshInFlight = null,
  );

  Future<bool> _refreshOnce() async {
    final rt = _refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final session = await _api.refresh(rt);
      await _apply(session, persist: _persistSession);
      return true;
    } on AuthException catch (e) {
      // Only a definitive rejection (a 4xx from the refresh endpoint) means the
      // refresh token is truly dead — then sign out. A transient network/timeout
      // error surfaces with a null statusCode (and a server 5xx is not the
      // token's fault); in those cases keep the stored tokens so the user can
      // retry after the blip instead of being logged out of a valid session.
      final status = e.statusCode;
      if (status != null && status >= 400 && status < 500) {
        await signOut();
      }
      return false;
    }
  }

  /// Clear the session locally (the server is stateless for access tokens).
  Future<void> signOut() async {
    _user = null;
    _token = null;
    _refreshToken = null;
    await _store.clear();
    notifyListeners();
  }

  /// Updates onboarding [progress] (0..100), optionally marking the mandatory
  /// step complete. Optimistically updates the local user so routing and the
  /// dashboard progress card react immediately, then queues the backend write
  /// through the offline outbox. Best-effort: a failure won't block the UI.
  Future<void> updateOnboarding({
    int? progress,
    bool markMandatory = false,
  }) async {
    final user = _user;
    if (user == null) return;
    // Optimistic in-memory update so routing + the progress card react instantly.
    // Deliberately NOT persisted yet: writing before the backend confirms could
    // leave storage disagreeing with the server on a failure, so a reload would
    // route differently than a fresh login. The SyncEngine persists the
    // authoritative user (via [onServerUserConfirmed]) once the write lands.
    _user = user.copyWith(
      mandatoryCompleted: markMandatory ? true : null,
      onboardingProgress: progress,
    );
    notifyListeners();

    if (_token == null || _token!.isEmpty) return;
    // Enqueue the durable "sync" half; the engine replays it via [runAuthed]
    // (same refresh-on-401 path) and confirms the server user back to us.
    await SyncEngine.instance.enqueueProgress(
      progress: progress,
      mandatoryCompleted: markMandatory ? true : null,
    );
  }

  /// Runs an authenticated API call with the current token + refresh-on-401,
  /// exposing the private [_authed] to the SyncEngine so queued replays share
  /// the interactive path's single-flight token handling.
  Future<T> runAuthed<T>(Future<T> Function(String token) call) =>
      _authed(call);

  /// Persist an authoritative user returned by a confirmed server write (from
  /// the SyncEngine). Mirrors what [updateOnboarding] used to do inline, now
  /// that the network write is deferred to the outbox.
  Future<void> onServerUserConfirmed(AuthUser user) async {
    _user = user;
    await _persist();
    notifyListeners();
  }

  /// Sets the account [type] for the signed-in user (the Google/onboarding
  /// path). Persists the updated user locally on success. Throws an
  /// [AuthException] (with an `'email'` field error) when an organization
  /// account is chosen but the email is a free provider.
  Future<AuthUser> setAccountType(AccountType type) async {
    final updated = await _authed((t) => _api.setAccountType(t, type));
    _user = updated;
    await _persist();
    notifyListeners();
    return updated;
  }

  /// Runs an authenticated API call with the current access token, and on a 401
  /// (typically an expired access token) rotates the refresh token once and
  /// retries. Non-401 [AuthException]s (e.g. a 422 work-email rejection) pass
  /// straight through. Throws if there is no session or the refresh fails.
  Future<T> _authed<T>(Future<T> Function(String token) call) async {
    var token = _token;
    if (token == null || token.isEmpty) {
      throw const AuthException('You are not signed in.');
    }
    try {
      return await call(token);
    } on AuthException catch (e) {
      if (e.statusCode != 401) rethrow;
      if (!await refresh()) rethrow;
      token = _token;
      if (token == null || token.isEmpty) {
        throw const AuthException('You are not signed in.');
      }
      return await call(token);
    }
  }

  /// Whether a JWT's `exp` claim is in the past (with a small clock-skew
  /// buffer). Decoded locally to avoid a needless refresh when the token is
  /// still valid; an unparseable or missing `exp` is treated as expired so the
  /// caller rotates rather than sending a token the backend will reject.
  bool _isExpired(String token, {Duration skew = const Duration(seconds: 30)}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! int) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().add(skew).isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  Future<void> _apply(AuthSession session, {bool persist = true}) async {
    _user = session.user;
    _token = session.token;
    _refreshToken = session.refreshToken;
    _persistSession = persist;
    // Best-effort persistence: a storage failure (e.g. no secure context when
    // served over plain HTTP on web) must not fail an otherwise-good sign-in.
    // When [persist] is false ("Remember me" off) we clear instead, so the
    // session lives only in memory and a reload returns to the landing page.
    try {
      if (persist) {
        await _store.save(session);
      } else {
        await _store.clear();
      }
    } catch (e) {
      debugPrint('Session: token persistence failed: $e');
    }
    notifyListeners();
  }

  /// Re-save the current session (used after [completeOnboarding] updates the
  /// user). Respects "Remember me": a non-persisted session stays in memory.
  Future<void> _persist() async {
    if (!_persistSession) return;
    final user = _user;
    final token = _token;
    final refresh = _refreshToken;
    if (user == null || token == null || refresh == null) return;
    try {
      await _store.save(
        AuthSession(user: user, token: token, refreshToken: refresh),
      );
    } catch (e) {
      debugPrint('Session: persistence failed: $e');
    }
  }
}
