import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and deletes a single string value from the legacy plaintext
/// `SharedPreferences` store used by supabase_flutter's own
/// [SharedPreferencesLocalStorage] before this app switched to
/// [SecureSessionStorage] (issue #7).
///
/// This narrow seam exists so [SecureSessionStorage]'s one-time migration
/// can be unit tested without standing up a `SharedPreferencesAsync`
/// platform mock.
abstract class LegacySessionStore {
  Future<String?> read(String key);

  Future<void> remove(String key);
}

class _SharedPreferencesLegacySessionStore implements LegacySessionStore {
  const _SharedPreferencesLegacySessionStore();

  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Persists the Supabase session (including the refresh token) in platform
/// secure storage (Keychain on iOS/macOS, Keystore on Android) instead of
/// plaintext SharedPreferences, matching the raw JSON string contract used
/// by supabase_flutter's own [SharedPreferencesLocalStorage].
///
/// Before issue #7 (commit `0b3b626`), this app took supabase_flutter's own
/// default `localStorage`, [SharedPreferencesLocalStorage], which persists
/// the full session JSON (access token *and* refresh token) in plaintext
/// `SharedPreferences` under a key derived from the project URL:
/// `sb-<project-ref>-auth-token`. #7 switched storage to here but shipped no
/// migration for the old store or key, so upgrading users with a still-valid
/// session were silently signed out (secure storage was empty, so
/// [hasAccessToken] reported false) while the plaintext refresh token stayed
/// on disk, unread and unrevoked, indefinitely (issue #179).
///
/// [initialize] performs that one-time migration on every app start: it
/// reads the legacy key, writes it through to secure storage only if secure
/// storage doesn't already have a session, then deletes the legacy entry
/// unconditionally — so the plaintext copy is gone even for a user who
/// signed out (and so has no session to migrate) in between.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required String supabaseUrl,
    FlutterSecureStorage? storage,
    LegacySessionStore? legacySessionStore,
  }) : _legacyKey = _legacyKeyFor(supabaseUrl),
       _storage = storage ?? const FlutterSecureStorage(),
       _legacySessionStore =
           legacySessionStore ?? const _SharedPreferencesLegacySessionStore();

  final FlutterSecureStorage _storage;
  final LegacySessionStore _legacySessionStore;
  final String _legacyKey;

  static const _sessionKey = 'supabase.session';

  /// Derives the legacy `SharedPreferences` key the same way
  /// supabase_flutter's default `SharedPreferencesLocalStorage` does
  /// (`supabase_flutter-2.12.4/lib/src/supabase.dart:112-117`), from the
  /// configured Supabase URL rather than hardcoding the project ref, so this
  /// keeps working if a dev/staging/prod URL split lands later (issue #42).
  static String _legacyKeyFor(String supabaseUrl) {
    final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
    return 'sb-$projectRef-auth-token';
  }

  @override
  Future<void> initialize() async {
    final legacySession = await _legacySessionStore.read(_legacyKey);
    if (legacySession != null && !await hasAccessToken()) {
      await persistSession(legacySession);
    }
    // Delete the legacy entry unconditionally, whether or not it was
    // migrated, so the plaintext copy never lingers on disk.
    await _legacySessionStore.remove(_legacyKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    return _storage.containsKey(key: _sessionKey);
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: _sessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _sessionKey);
  }
}
