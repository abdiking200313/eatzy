import 'package:chowflow/platform/session/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'hasAccessToken and accessToken report nothing before a session is persisted',
    () async {
      final storage = SecureSessionStorage();

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    },
  );

  test('persistSession stores the session so it can be read back', () async {
    final storage = SecureSessionStorage();
    const sessionJson = '{"access_token":"token-123","refresh_token":"r"}';

    await storage.persistSession(sessionJson);

    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), sessionJson);
  });

  test('removePersistedSession clears the stored session', () async {
    final storage = SecureSessionStorage();
    await storage.persistSession('{"access_token":"token-123"}');

    await storage.removePersistedSession();

    expect(await storage.hasAccessToken(), isFalse);
    expect(await storage.accessToken(), isNull);
  });
}
