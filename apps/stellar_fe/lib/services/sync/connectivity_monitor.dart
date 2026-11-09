import 'package:connectivity_plus/connectivity_plus.dart';

// =========================================================================
// ATVETI STELLAR — Connectivity monitor
//
// Thin wrapper over connectivity_plus that collapses the platform's list of
// active transports into a single online/offline signal. Used by the
// SyncEngine to flush the outbox proactively when the network returns.
//
// Note: connectivity_plus reports the presence of a transport, not real
// reachability — the engine still relies on request-level errors as the final
// arbiter. This only tells us *when to try*.
// =========================================================================
class ConnectivityMonitor {
  ConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Emits `true` when at least one transport is active, `false` when offline.
  Stream<bool> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  /// The current best-effort online state.
  Future<bool> isOnline() async =>
      _isOnline(await _connectivity.checkConnectivity());

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
