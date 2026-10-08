import 'package:chowflow/platform/session/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _supabaseUrl = 'https://jzubookmbrtslocuzepe.supabase.co';
const _legacyKey = 'sb-jzubookmbrtslocuzepe-auth-token';

/// An in-memory [LegacySessionStore] so the migration in
/// [SecureSessionStorage.initialize] can be tested without a
/// `SharedPreferencesAsync` platform mock.
class _FakeLegacySessionStore implements LegacySessionStore {
  _FakeLegacySessionStore([Map<String, String>? initialValues])
    : _values = Map<String, String>.from(initialValues ?? const {});

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> remove(String key) async => _values.remove(key);

  bool containsKey(String key) => _values.containsKey(key);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'hasAccessToken and accessToken report nothing before a session is persisted',
    () async {
      final storage = SecureSessionStorage(
        supabaseUrl: _supabaseUrl,
        legacySessionStore: _FakeLegacySessionStore(),
      );

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    },
  );

  test('persistSession stores the session so it can be read back', () async {
    final storage = SecureSessionStorage(
      supabaseUrl: _supabaseUrl,
      legacySessionStore: _FakeLegacySessionStore(),
    );
    const sessionJson = '{"access_token":"token-123","refresh_token":"r"}';

    await storage.persistSession(sessionJson);

    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), sessionJson);
  });

  test('removePersistedSession clears the stored session', () async {
    final storage = SecureSessionStorage(
      supabaseUrl: _supabaseUrl,
      legacySessionStore: _FakeLegacySessionStore(),
    );
    await storage.persistSession('{"access_token":"token-123"}');

    await storage.removePersistedSession();

    expect(await storage.hasAccessToken(), isFalse);
    expect(await storage.accessToken(), isNull);
  });

  group('initialize (pre-#7 plaintext session migration, issue #179)', () {
    test('migrates the legacy plaintext session into secure storage when only '
        'the legacy key exists', () async {
      const legacySessionJson =
          '{"access_token":"legacy-token","refresh_token":"legacy-r"}';
      final legacyStore = _FakeLegacySessionStore({
        _legacyKey: legacySessionJson,
      });
      final storage = SecureSessionStorage(
        supabaseUrl: _supabaseUrl,
        legacySessionStore: legacyStore,
      );

      await storage.initialize();

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), legacySessionJson);
    });

    test(
      'does not clobber a session already present in secure storage',
      () async {
        const legacySessionJson = '{"access_token":"legacy-token"}';
        const currentSessionJson = '{"access_token":"current-token"}';
        final legacyStore = _FakeLegacySessionStore({
          _legacyKey: legacySessionJson,
        });
        final storage = SecureSessionStorage(
          supabaseUrl: _supabaseUrl,
          legacySessionStore: legacyStore,
        );
        await storage.persistSession(currentSessionJson);

        await storage.initialize();

        expect(await storage.accessToken(), currentSessionJson);
      },
    );

    test('deletes the legacy key after migrating it', () async {
      final legacyStore = _FakeLegacySessionStore({
        _legacyKey: '{"access_token":"legacy-token"}',
      });
      final storage = SecureSessionStorage(
        supabaseUrl: _supabaseUrl,
        legacySessionStore: legacyStore,
      );

      await storage.initialize();

      expect(legacyStore.containsKey(_legacyKey), isFalse);
    });

    test('deletes the legacy key even when a secure session already exists '
        '(no migration happens)', () async {
      final legacyStore = _FakeLegacySessionStore({
        _legacyKey: '{"access_token":"legacy-token"}',
      });
      final storage = SecureSessionStorage(
        supabaseUrl: _supabaseUrl,
        legacySessionStore: legacyStore,
      );
      await storage.persistSession('{"access_token":"current-token"}');

      await storage.initialize();

      expect(legacyStore.containsKey(_legacyKey), isFalse);
    });

    test('deletes the legacy key even when it was never present (no-op '
        'removal, e.g. a user who signed out before upgrading)', () async {
      final legacyStore = _FakeLegacySessionStore();
      final storage = SecureSessionStorage(
        supabaseUrl: _supabaseUrl,
        legacySessionStore: legacyStore,
      );

      await storage.initialize();

      expect(await storage.hasAccessToken(), isFalse);
      expect(legacyStore.containsKey(_legacyKey), isFalse);
    });

    test('derives the legacy key from the configured Supabase URL', () async {
      final legacyStore = _FakeLegacySessionStore({
        'sb-otherproject-auth-token': '{"access_token":"legacy-token"}',
      });
      final storage = SecureSessionStorage(
        supabaseUrl: 'https://otherproject.supabase.co',
        legacySessionStore: legacyStore,
      );

      await storage.initialize();

      expect(await storage.hasAccessToken(), isTrue);
      expect(legacyStore.containsKey('sb-otherproject-auth-token'), isFalse);
    });
  });
}
