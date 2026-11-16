// =========================================================================
// JosJob — Backend configuration
//
// Runtime config for talking to the Josjob backend (see docs/api/auth.md).
// Override at build/run time with --dart-define, e.g.:
//
//   flutter run -d chrome \
//     --dart-define=API_BASE_URL=http://localhost:4000 \
//     --dart-define=GOOGLE_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
// =========================================================================
class ApiConfig {
  ApiConfig._();

  /// Backend base URL. Defaults to the local dev server.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  /// Google **Web** OAuth client ID — the audience the backend validates
  /// (`GOOGLE_CLIENT_ID`). Empty disables the Google sign-in button.
  ///
  /// Baked in at BUILD time, so setting the CI/CD variable alone does not
  /// update a deployed bundle — the FE image must be rebuilt for it to take effect.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static bool get hasGoogleClientId => googleClientId.isNotEmpty;
}
