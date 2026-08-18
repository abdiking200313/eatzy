import 'dart:convert';

import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PKCE is the client's default auth flow, and it requires an async-storage
// implementation to persist the code verifier. Production code gets one for
// free from `Supabase.initialize`; these unit tests don't run through that,
// so every injected client opts into the implicit flow instead, which skips
// storage entirely and keeps these tests independent of platform channels.
const _testAuthOptions = AuthClientOptions(authFlowType: AuthFlowType.implicit);

void main() {
  test('AuthService accepts an injected Supabase client', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      authOptions: _testAuthOptions,
    );
    final service = AuthService(client: client);

    expect(service.getCurrentUserId(), isNull);
    expect(service.getCurrentUserEmail(), isNull);
  });

  test(
    'passwordRecoveryRedirectUrl matches the configured deep link scheme',
    () {
      // Must stay in sync with the intent-filter/URL-scheme configured in
      // android/app/src/main/AndroidManifest.xml and ios/Runner/Info.plist.
      expect(AuthService.passwordRecoveryRedirectUrl, 'zivo://reset-callback');
    },
  );

  test(
    'resetPasswordForEmail posts to the recover endpoint with the recovery redirect',
    () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: mockClient,
      );
      final service = AuthService(client: client);

      await service.resetPasswordForEmail('user@example.com');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/auth/v1/recover');
      expect(
        capturedRequest!.url.queryParameters['redirect_to'],
        AuthService.passwordRecoveryRedirectUrl,
      );
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['email'], 'user@example.com');
    },
  );

  test('updatePassword requires an authenticated session', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      authOptions: _testAuthOptions,
    );
    final service = AuthService(client: client);

    // No session has been established, so this must fail locally rather
    // than silently succeeding or hitting the network - it documents that
    // updatePassword relies on an active session (normal login or a
    // password-recovery session) instead of a separate current-password
    // check.
    await expectLater(
      () => service.updatePassword('a-new-password'),
      throwsA(isA<AuthSessionMissingException>()),
    );
  });
}
