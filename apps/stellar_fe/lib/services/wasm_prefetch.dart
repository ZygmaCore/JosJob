// =========================================================================
// ATVETI STELLAR — WASM prefetch (facade)
//
// On web, Drift downloads web/sqlite3.wasm (~748 KB) the first time the outbox
// database opens, and exposes no progress callback. [prefetchSqliteWasm]
// downloads that same asset up-front with a streamed fetch so a boot splash can
// show real download progress — and, as a side effect, warms the browser HTTP
// cache so Drift's own load is then a cache hit.
//
// The implementation is chosen by a conditional import: the web build streams
// the bytes (wasm_prefetch_web.dart); every other platform bundles sqlite3
// natively and gets an immediate no-op (wasm_prefetch_stub.dart).
// =========================================================================

export 'wasm_progress.dart';
export 'wasm_prefetch_stub.dart'
    if (dart.library.js_interop) 'wasm_prefetch_web.dart';
