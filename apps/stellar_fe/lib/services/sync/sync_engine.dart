import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../auth_api.dart';
import '../session.dart';
import 'connectivity_monitor.dart';
import 'outbox_store.dart';

// =========================================================================
// ATVETI STELLAR — Sync engine (offline-first "save then sync")
//
// Fire-and-forget mutations are enqueued into a persistent [OutboxStore] and
// replayed against the backend when possible. The optimistic in-memory update
// (done by the caller, e.g. Session.updateOnboarding) gives instant UX; this
// engine owns the durable "sync" half.
//
// Flush triggers: after each enqueue, on app startup, on sign-in (Session is a
// ChangeNotifier), and on connectivity returning. Replays reuse Session's
// token + single-flight refresh-on-401 via [Session.runAuthed], so the queue
// never hand-rolls token handling.
//
// Delivery is at-least-once; every queued mutation is an idempotent SET
// (absolute progress / full-document answers with last-write-wins), so a
// replay of the same payload is a no-op. Transient failures (offline / 5xx)
// keep the row and back off; a permanent 4xx parks the row so it stops
// retrying but stays visible.
// =========================================================================

/// Mutation type tags stored on each outbox row.
const String kMutationProgress = 'onboarding_progress';
const String kMutationAnswers = 'onboarding_answers';

class SyncEngine {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  OutboxStore? _store;
  AuthApi _api = AuthApi();
  Session _session = Session.instance;
  ConnectivityMonitor _connectivity = ConnectivityMonitor();
  final Uuid _uuid = const Uuid();

  StreamSubscription<bool>? _connSub;
  Timer? _retryTimer;
  Future<void>? _flushInFlight;
  bool _started = false;
  bool _lastSignedIn = false;

  /// Wire in the collaborators + start the flush triggers. Idempotent. Test
  /// seams (store/api/session/connectivity) may be overridden; the app calls it
  /// with no arguments after [Session.restore].
  void start({
    OutboxStore? store,
    AuthApi? api,
    Session? session,
    ConnectivityMonitor? connectivity,
  }) {
    if (store != null) _store = store;
    if (api != null) _api = api;
    if (session != null) _session = session;
    if (connectivity != null) _connectivity = connectivity;
    _store ??= DriftOutboxStore();

    if (_started) return;
    _started = true;

    _lastSignedIn = _session.isSignedIn;
    _session.addListener(_onSessionChanged);
    _connSub = _connectivity.onStatusChanged.listen((online) {
      if (online) _kick();
    });

    // Startup flush for anything left over from a previous run.
    _kick();
  }

  /// Enqueue an onboarding progress SET and try to flush. The caller keeps the
  /// optimistic in-memory update; this only schedules the durable write.
  Future<void> enqueueProgress({int? progress, bool? mandatoryCompleted}) =>
      _enqueue(kMutationProgress, {
        'progress': progress,
        'mandatory_completed': mandatoryCompleted,
      });

  /// Enqueue a full-document onboarding answers PUT and try to flush. Stamps a
  /// client timestamp so the backend can apply last-write-wins.
  Future<void> enqueueAnswers(Map<String, dynamic> answers) =>
      _enqueue(kMutationAnswers, {
        'answers': answers,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<void> _enqueue(String type, Map<String, dynamic> payload) async {
    final store = _store;
    if (store == null) return; // engine not started yet
    try {
      await store.enqueue(
        OutboxRecord(
          id: _uuid.v4(),
          type: type,
          payload: jsonEncode(payload),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      // A storage failure must not break the optimistic UX (mirrors the
      // best-effort persistence elsewhere in the app).
      debugPrint('SyncEngine: enqueue failed: $e');
      return;
    }
    _kick();
  }

  void _onSessionChanged() {
    final signedIn = _session.isSignedIn;
    if (signedIn && !_lastSignedIn) _kick();
    _lastSignedIn = signedIn;
  }

  // Fire-and-forget flush.
  void _kick() {
    unawaited(flush());
  }

  /// Drain the outbox. Single-flight so overlapping triggers coalesce. Never
  /// throws.
  Future<void> flush() => _flushInFlight ??= _flush().whenComplete(() {
    _flushInFlight = null;
  });

  Future<void> _flush() async {
    if (!_session.isSignedIn) return;
    final store = _store;
    if (store == null) return;

    final List<OutboxRecord> rows;
    try {
      rows = await store.pending();
    } catch (e) {
      debugPrint('SyncEngine: reading outbox failed: $e');
      return;
    }

    for (final row in rows) {
      try {
        await _replay(row);
        await store.delete(row.id);
      } on AuthException catch (e) {
        await store.bumpAttempts(row.id);
        final status = e.statusCode;
        if (status == null || status >= 500) {
          // Offline / transient / server error: keep the row and back off.
          _scheduleRetry(row.attempts + 1);
          return;
        }
        if (status == 401) {
          // Refresh already attempted inside runAuthed; the session is now
          // signed out or still rejected. Stop; a later sign-in re-triggers.
          return;
        }
        // Permanent client error (400/403/404/409/422): park and move on so
        // one bad row never blocks the queue or retries forever.
        await store.park(row.id);
      } catch (e) {
        // Unexpected (e.g. a malformed payload). Park rather than loop.
        debugPrint('SyncEngine: replay error, parking row: $e');
        await store.park(row.id);
      }
    }
  }

  Future<void> _replay(OutboxRecord row) async {
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    switch (row.type) {
      case kMutationProgress:
        final user = await _session.runAuthed(
          (t) => _api.updateOnboarding(
            t,
            progress: (payload['progress'] as num?)?.toInt(),
            mandatoryCompleted: payload['mandatory_completed'] as bool?,
          ),
        );
        // The server returned the authoritative user; persist it so a reload
        // agrees with the backend (the optimistic value was never persisted).
        await _session.onServerUserConfirmed(user);
      case kMutationAnswers:
        await _session.runAuthed(
          (t) => _api.putAnswers(
            t,
            answers: (payload['answers'] as Map).cast<String, dynamic>(),
            updatedAt: payload['updated_at'] as String,
          ),
        );
      default:
        // Unknown type: delete by returning normally so it can't wedge the
        // queue (delete happens in the caller on success).
        return;
    }
  }

  void _scheduleRetry(int attempts) {
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff(attempts), _kick);
  }

  // Exponential backoff capped at 60s: 2s, 4s, 8s, ... 60s.
  Duration _backoff(int attempts) {
    final capped = attempts.clamp(1, 6);
    final seconds = (1 << capped).clamp(2, 60);
    return Duration(seconds: seconds);
  }

  /// Release listeners/timers (mainly for tests).
  void dispose() {
    _retryTimer?.cancel();
    _connSub?.cancel();
    _session.removeListener(_onSessionChanged);
    _started = false;
  }
}
