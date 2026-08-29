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

/// Builds a minimal-but-valid GoTrue `/token` or `/signup` success body:
/// an access/refresh token pair plus the smallest `user` object that
/// `User.fromJson` accepts (id, aud, app/user metadata, created_at).
Map<String, dynamic> _sessionJson({
  required String userId,
  required String email,
}) {
  final now = DateTime.now().toIso8601String();
  return {
    'access_token': 'mock-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'mock-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': now,
    },
  };
}

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

  test(
    'signInWithEmailPassword establishes a session on valid credentials',
    () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(
            _sessionJson(userId: 'mock-user-id', email: 'user@example.com'),
          ),
          200,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: mockClient,
      );
      final service = AuthService(client: client);

      final response = await service.signInWithEmailPassword(
        'user@example.com',
        'correct-password',
      );

      expect(response.session, isNotNull);
      expect(service.getCurrentUserId(), 'mock-user-id');
      expect(service.getCurrentUserEmail(), 'user@example.com');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/auth/v1/token');
      expect(capturedRequest!.url.queryParameters['grant_type'], 'password');
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['email'], 'user@example.com');
      expect(body['password'], 'correct-password');
    },
  );

  test(
    'signInWithEmailPassword throws AuthApiException for invalid credentials '
    'and leaves no session behind',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Invalid login credentials',
            'error_code': 'invalid_credentials',
          }),
          400,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: mockClient,
      );
      final service = AuthService(client: client);

      await expectLater(
        () => service.signInWithEmailPassword(
          'user@example.com',
          'wrong-password',
        ),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.statusCode, 'statusCode', '400')
              .having((e) => e.code, 'code', 'invalid_credentials'),
        ),
      );
      expect(service.getCurrentUserId(), isNull);
      expect(service.getCurrentUserEmail(), isNull);
    },
  );

  test(
    'signUpWithEmailPassword establishes a session for a brand-new user',
    () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(
            _sessionJson(userId: 'new-user-id', email: 'new@example.com'),
          ),
          200,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: mockClient,
      );
      final service = AuthService(client: client);

      final response = await service.signUpWithEmailPassword(
        'new@example.com',
        'a-strong-password',
      );

      expect(response.session, isNotNull);
      expect(service.getCurrentUserId(), 'new-user-id');
      expect(service.getCurrentUserEmail(), 'new@example.com');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/auth/v1/signup');
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['email'], 'new@example.com');
      expect(body['password'], 'a-strong-password');
    },
  );

  test(
    'signUpWithEmailPassword throws AuthApiException for a duplicate email',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error_code': 'user_already_exists',
            'msg': 'User already registered',
          }),
          422,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: mockClient,
      );
      final service = AuthService(client: client);

      await expectLater(
        () => service.signUpWithEmailPassword(
          'existing@example.com',
          'a-strong-password',
        ),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.statusCode, 'statusCode', '422')
              .having((e) => e.code, 'code', 'user_already_exists'),
        ),
      );
      expect(service.getCurrentUserId(), isNull);
    },
  );

  test('signOut clears the current session state', () async {
    final requestedPaths = <String>[];
    final mockClient = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/auth/v1/logout') {
        return http.Response('', 204);
      }
      return http.Response(
        jsonEncode(
          _sessionJson(userId: 'mock-user-id', email: 'user@example.com'),
        ),
        200,
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      authOptions: _testAuthOptions,
      httpClient: mockClient,
    );
    final service = AuthService(client: client);

    await service.signInWithEmailPassword(
      'user@example.com',
      'correct-password',
    );
    expect(service.getCurrentUserId(), isNotNull);
    expect(service.getCurrentUserEmail(), isNotNull);

    await service.signOut();

    expect(service.getCurrentUserId(), isNull);
    expect(service.getCurrentUserEmail(), isNull);
    // Signing out with an active session should also revoke it server-side,
    // not just forget it locally.
    expect(requestedPaths, contains('/auth/v1/logout'));
  });
}
