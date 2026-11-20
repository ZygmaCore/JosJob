import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local UI preferences are explicitly device-local and partitioned by account.
class UiPreferences {
  final FlutterSecureStorage storage;
  const UiPreferences({this.storage = const FlutterSecureStorage()});
  Future<Set<String>> savedCourses(String userId) async {
    final raw = await storage.read(key: 'josjob.saved_courses.$userId');
    try {
      final list = jsonDecode(raw ?? '[]');
      return list is List ? list.whereType<String>().toSet() : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> saveCourses(String userId, Set<String> ids) => storage.write(
    key: 'josjob.saved_courses.$userId',
    value: jsonEncode(ids.toList()),
  );
}

class AuthContinuation {
  static const _key = 'josjob.auth_destination';
  static const _storage = FlutterSecureStorage();
  static Future<void> _pending = Future.value();
  static String? destination;
  static String? validate(String? value) {
    if (value == null ||
        value.length > 2048 ||
        !value.startsWith('/') ||
        value.startsWith('//')) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
      return null;
    }
    const roots = {
      'jobs',
      'applications',
      'chats',
      'dashboard',
      'documents',
      'explore',
      'coaching',
    };
    return uri.pathSegments.isNotEmpty && roots.contains(uri.pathSegments.first)
        ? uri.toString()
        : null;
  }

  static Future<void> restore() async {
    try {
      destination = validate(await _storage.read(key: _key));
    } catch (_) {
      destination = null;
    }
  }

  static Future<void> remember(String value) {
    destination = validate(value);
    final next = destination;
    return _pending = _pending.then((_) async {
      try {
        await _storage.write(key: _key, value: next);
      } catch (_) {
        /* Memory still supports this sign-in. */
      }
    });
  }

  static Future<String?> take() async {
    final value = destination;
    await clear();
    return value;
  }

  static Future<void> clear() async {
    destination = null;
    await _pending;
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      /* Best effort. */
    }
  }
}
