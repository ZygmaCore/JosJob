import 'wasm_progress.dart';

// =========================================================================
// Native prefetch (no-op). iOS/Android/macOS/Windows/Linux bundle sqlite3 via
// sqlite3_flutter_libs — there is no wasm to download — so this completes
// immediately with a single terminal sample. Selected by the conditional
// import in wasm_prefetch.dart for every non-web build.
// =========================================================================

/// No-op on native: yields a single terminal [WasmProgress] so callers can
/// treat every platform uniformly.
Stream<WasmProgress> prefetchSqliteWasm() async* {
  yield const WasmProgress(done: true);
}
