// =========================================================================
// JosJob — WASM prefetch progress
//
// Progress of the one-time download of the web SQLite engine (sqlite3.wasm)
// that Drift needs on web. Shared by the platform prefetch implementations
// (see wasm_prefetch.dart) and the boot splash that renders it.
// =========================================================================

/// A single progress sample for the sqlite3.wasm prefetch.
class WasmProgress {
  /// Bytes received so far.
  final int received;

  /// Total bytes to download when the server reports an (uncompressed)
  /// `Content-Length`; null when unknown, in which case progress is
  /// indeterminate.
  final int? total;

  /// The terminal sample: the prefetch has finished (or given up). The gate
  /// reveals the app on this (or when the stream simply closes).
  final bool done;

  const WasmProgress({this.received = 0, this.total, this.done = false});

  /// Completion fraction in 0..1, or null when [total] is unknown (drives an
  /// indeterminate progress bar).
  double? get fraction {
    final t = total;
    if (t == null || t <= 0) return null;
    return (received / t).clamp(0.0, 1.0);
  }
}
