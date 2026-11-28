import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'wasm_progress.dart';

// =========================================================================
// Web prefetch — streams sqlite3.wasm with the browser Fetch API so the boot
// splash can show real download progress, and so the browser HTTP cache is
// warm before Drift opens the outbox DB (its own fetch then hits the cache).
//
// The URL mirrors the relative URI Drift resolves in
// lib/services/sync/outbox_db.dart (`Uri.parse('sqlite3.wasm')`) so both
// resolve against the same base href and share one cache entry.
//
// Everything here is best-effort: any failure just ends the stream so startup
// is never blocked — Drift still fetches the wasm itself when the DB opens.
// Selected by the conditional import in wasm_prefetch.dart for web builds.
// =========================================================================

/// The asset Drift loads for its WASM sqlite (see outbox_db.dart).
const String _wasmUrl = 'sqlite3.wasm';

@JS('fetch')
external JSPromise<web.Response> _fetch(JSAny input, web.RequestInit init);

/// Streams download progress while prefetching sqlite3.wasm on web.
Stream<WasmProgress> prefetchSqliteWasm() async* {
  // Abort the transfer if the stream is cancelled (e.g. the boot gate's
  // backstop reveals the app first) so we don't keep pulling ~748 KB in
  // parallel with Drift's own load on the slow links this feature targets.
  final abort = web.AbortController();
  try {
    final resp = await _fetch(
      _wasmUrl.toJS,
      web.RequestInit(signal: abort.signal),
    ).toDart;
    if (!resp.ok) return; // 4xx/5xx: give up quietly, Drift will retry later.

    // A transfer-compressed response reports the *encoded* length, which won't
    // match the decoded bytes we read below — so treat it as unknown-total
    // (indeterminate) rather than showing a bogus > 100%.
    final encoding = resp.headers.get('content-encoding');
    final lengthHeader = resp.headers.get('content-length');
    final total = (encoding == null || encoding.isEmpty)
        ? int.tryParse(lengthHeader ?? '')
        : null;

    final body = resp.body;
    if (body == null) {
      // No readable stream: still drain the body to warm the cache, then done.
      await resp.arrayBuffer().toDart;
      yield WasmProgress(received: total ?? 0, total: total, done: true);
      return;
    }

    final reader = body.getReader() as web.ReadableStreamDefaultReader;
    var received = 0;
    yield WasmProgress(received: 0, total: total);
    while (true) {
      final chunk = await reader.read().toDart;
      if (chunk.done) break;
      final value = chunk.value;
      if (value != null) {
        received += (value as JSUint8Array).toDart.length;
        yield WasmProgress(received: received, total: total);
      }
    }
    yield WasmProgress(
      received: received,
      total: total ?? received,
      done: true,
    );
  } catch (_) {
    // Best-effort: never let a prefetch failure block startup.
    yield const WasmProgress(done: true);
  } finally {
    // No-op once the download has completed; aborts it if we were cancelled
    // mid-flight.
    abort.abort();
  }
}
