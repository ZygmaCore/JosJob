import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/wasm_prefetch.dart';
import '../theme/app_theme.dart';

part 'widgets/boot_splash.dart';

// =========================================================================
// JosJob — App bootstrap gate
//
// Gates the app behind a one-time prefetch of the web SQLite engine. On web it
// shows the branded [_BootSplash] with real download progress while
// sqlite3.wasm streams in (warming the HTTP cache so Drift opens instantly),
// then reveals [child] — but never before a short minimum splash time, so a
// fast/cache-hit load doesn't just flash by. On native — where sqlite3 is
// bundled — it reveals [child] immediately. [onReady] fires once, at reveal, so
// the caller can start work that touches the database (e.g. the sync engine)
// only once the engine is warm.
//
// The prefetch is best-effort: failures, and a backstop timeout, simply reveal
// the app anyway (Drift will fetch the wasm itself when the DB first opens).
// =========================================================================

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, required this.child, this.onReady});

  /// The real first screen, revealed once the engine is ready.
  final Widget child;

  /// Called exactly once at reveal (after the prefetch settles and the minimum
  /// splash time; fires post-first-frame on native).
  final VoidCallback? onReady;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  // Backstop so a stalled network never wedges the splash forever.
  static const _backstopTimeout = Duration(seconds: 15);
  // Keep the splash up at least this long so a fast/cache-hit load doesn't just
  // flash by; a load that already takes longer isn't delayed any further.
  static const _minSplashTime = Duration(seconds: 1);

  StreamSubscription<WasmProgress>? _sub;
  Timer? _backstop;
  Timer? _minTimer;
  WasmProgress _progress = const WasmProgress();
  bool _settled = false; // prefetch finished / aborted (wasm warm, or gave up)
  bool _minElapsed = false; // the minimum splash time has passed
  bool _ready = false; // app revealed

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Native bundles sqlite3 — nothing to download; reveal immediately but
      // still honour the onReady contract after the first frame.
      _ready = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onReady?.call(),
      );
      return;
    }
    _minTimer = Timer(_minSplashTime, () {
      _minElapsed = true;
      _maybeReveal();
    });
    _backstop = Timer(_backstopTimeout, _settle);
    _sub = prefetchSqliteWasm().listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
        if (p.done) _settle();
      },
      onDone: _settle,
      onError: (_) => _settle(),
    );
  }

  // The prefetch has finished, errored, or hit the backstop. Stop pumping
  // progress and abort any in-flight download (the web prefetch aborts its
  // fetch when its stream is cancelled), then reveal once the min time is up.
  void _settle() {
    if (_settled) return;
    _settled = true;
    _backstop?.cancel();
    _sub?.cancel();
    _maybeReveal();
  }

  // Reveal only once BOTH the prefetch has settled and the minimum splash time
  // has elapsed.
  void _maybeReveal() {
    if (_ready || !_settled || !_minElapsed) return;
    _ready = true;
    _minTimer?.cancel();
    widget.onReady?.call();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _backstop?.cancel();
    _minTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : _BootSplash(progress: _progress);
}
