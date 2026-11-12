import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// =========================================================================
// JosJob — Onboarding draft store
//
// Persists an in-progress onboarding "draft" (the user's answers) in secure
// storage, keyed by user id, so "Continue onboarding" restores the selections
// and inputs already entered. Client-side only (per-browser); the answers are
// not yet synced to the backend.
// =========================================================================
class OnboardingDraftStore {
  OnboardingDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'josjob.onboarding_draft.$userId';

  Future<void> save(String userId, String json) =>
      _storage.write(key: _key(userId), value: json);

  Future<String?> load(String userId) => _storage.read(key: _key(userId));

  Future<void> clear(String userId) => _storage.delete(key: _key(userId));
}
