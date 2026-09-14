import 'dart:convert';

import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same technique as delivery_address_repository_test.dart /
// activity_repository_test.dart / auth_service_test.dart: a real
// SupabaseClient wired to an http.testing.MockClient, so these tests
// exercise the actual PostgREST request path (method, URL, body) that
// SupabaseProfileRepository.deleteAccount sends, without a network call.
const _testAuthOptions = AuthClientOptions(authFlowType: AuthFlowType.implicit);

/// A syntactically valid (but unsigned) JWT good enough for
/// `Session.isExpired`/`Jwt.parseJwt`, which only base64-decode the payload
/// and never verify the signature.
String _fakeAccessToken(String userId, {int expiresInSeconds = 3600}) {
  String segment(Map<String, dynamic> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');

  final exp =
      DateTime.now()
          .add(Duration(seconds: expiresInSeconds))
          .millisecondsSinceEpoch ~/
      1000;
  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  final payload = segment({'sub': userId, 'exp': exp});
  return '$header.$payload.test-signature';
}

/// A [SupabaseClient] that appears signed in as [userId] (via
/// `recoverSession`, which sets the session locally without a network call
/// for a non-expired token) and routes all REST calls through [httpClient].
Future<SupabaseClient> _signedInClient({
  required String userId,
  required http.Client httpClient,
}) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    authOptions: _testAuthOptions,
    httpClient: httpClient,
  );
  final sessionJson = jsonEncode({
    'access_token': _fakeAccessToken(userId),
    'token_type': 'bearer',
    'refresh_token': 'test-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    },
  });
  await client.auth.recoverSession(sessionJson);
  return client;
}

void main() {
  group('SupabaseProfileRepository.deleteAccount', () {
    test('POSTs to the delete_own_account RPC and passes no parameters — the '
        "function is security definer and scopes itself to the caller's own "
        'auth.uid() server-side', () async {
      http.Request? capturedRequest;
      String? capturedBody;

      final client = await _signedInClient(
        userId: 'customer-1',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          capturedBody = request.body;
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final repository = SupabaseProfileRepository(client: client);

      await repository.deleteAccount();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(
        capturedRequest!.url.toString(),
        'https://example.supabase.co/rest/v1/rpc/delete_own_account',
      );
      // No params object is sent — the RPC takes no arguments, deriving
      // its target row from auth.uid() inside the function body instead
      // of trusting anything the client supplies. postgrest-dart encodes
      // the absent `params` as a literal JSON `null` body.
      expect(capturedBody, 'null');
    });

    test('surfaces a PostgrestException from a failed RPC call', () async {
      final client = await _signedInClient(
        userId: 'customer-2',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Authentication required', 'code': '42501'}),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final repository = SupabaseProfileRepository(client: client);

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('throws a StateError instead of calling the RPC when no user is '
        'signed in', () async {
      var requestSent = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: MockClient((request) async {
          requestSent = true;
          return http.Response('null', 200);
        }),
      );
      final repository = SupabaseProfileRepository(client: client);

      await expectLater(repository.deleteAccount(), throwsA(isA<StateError>()));
      expect(requestSent, isFalse);
    });
  });
}
