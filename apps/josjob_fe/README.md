# josjob frontend

JosJob — unified frontend for the Online Learning and AI Job Placement
products.

## Running locally (backend URL + Google sign-in)

`API_BASE_URL` and `GOOGLE_CLIENT_ID` are compile-time constants baked in by
Dart's `String.fromEnvironment` (see `lib/services/api_config.dart`). If
`GOOGLE_CLIENT_ID` is empty the Google button intentionally falls back to a
disabled "coming soon" pill.

Configure both with a local defines file (kept out of git):

```bash
cp dart_defines.example.json dart_defines.local.json
# edit dart_defines.local.json: set your backend URL and Google **Web** OAuth
# client ID (e.g. xxxx.apps.googleusercontent.com; leave "" to keep Google off).

flutter run -d chrome --dart-define-from-file=dart_defines.local.json
```

Or pass them inline: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000 --dart-define=GOOGLE_CLIENT_ID=<id>.apps.googleusercontent.com`.

**Deployment:** CI bakes these per branch from CI/CD variables
(Settings → CI/CD → Variables): `DEV_API_BASE_URL` / `PROD_API_BASE_URL` and
`DEV_GOOGLE_CLIENT_ID` / `PROD_GOOGLE_CLIENT_ID`. A single flat `GOOGLE_CLIENT_ID`
also works as a fallback for both branches. Set `DEV_GOOGLE_CLIENT_ID` (and add
the dev origin to the client ID's authorized JavaScript origins) to enable
Google sign-in on the dev deployment — the build log prints whether it's active.

## Drift web assets (`web/sqlite3.wasm`, `web/drift_worker.js`)

Drift needs two vendored binaries in `web/`, and they MUST match the pinned
package versions or the browser fails with `WebAssembly.instantiate(): Import …
"env": module is not an object`:

- `web/drift_worker.js` — from the **drift** version (`.pub-cache/.../drift-<ver>/drift_worker.js`).
- `web/sqlite3.wasm` — from the **sqlite3** version's release:
  `https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<ver>/sqlite3.wasm`
  (currently sqlite3 3.4.0). This is the same wasm drift bundles under
  `drift-<ver>/extension/devtools/build/sqlite3.wasm`.

Refresh both after bumping `drift`/`sqlite3` in `pubspec.yaml`.

On web, `AppBootstrap` (`lib/bootstrap/`) prefetches `sqlite3.wasm` at startup
with a streamed fetch and shows a branded progress splash, then reveals the app;
this also warms the browser HTTP cache so Drift's own load is a cache hit. It's
best-effort (native and any fetch failure fall straight through), so it needs no
configuration — just keep `web/sqlite3.wasm` in place per the notes above.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
