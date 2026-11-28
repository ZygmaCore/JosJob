// =========================================================================
// JosJob — open a URL in a new tab (facade)
//
// Opens an external document/video URL. The implementation is chosen by a
// conditional import: on web it opens a new browser tab (open_link_web.dart);
// every other platform gets a no-op (open_link_stub.dart). Mirrors the
// wasm_prefetch conditional-import pattern so no extra dependency is needed.
// =========================================================================

export 'open_link_stub.dart' if (dart.library.js_interop) 'open_link_web.dart';
