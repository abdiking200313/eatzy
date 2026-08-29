import 'dart:convert';

import 'package:chowflow/platform/activity/data/activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same technique as auth_service_test.dart: a real SupabaseClient wired to
// an http.testing.MockClient so these tests exercise the actual PostgREST
// request/response path (fluent query builder included) without a network
// call, rather than mocking SupabaseClient's internals directly.
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
  test('fetchActivities skips a malformed row and still returns the good ones '
      '(#62)', () async {
    final rows = [
      {
        'id': 'good-1',
        'profile_id': 'user-1',
        'service_id': 'food',
        'title': 'Food order',
        'subtitle': null,
        'status': 'Delivered',
        'occurred_at': DateTime.utc(2026, 8, 1).toIso8601String(),
        'amount': 12.5,
        'details_route': '/food',
      },
      // Malformed: title is missing/blank, which throws inside
      // ActivityItem.fromMap. This row must be skipped, not blank the
      // whole batch.
      {
        'id': 'bad-1',
        'profile_id': 'user-1',
        'service_id': 'food',
        'title': '',
        'subtitle': null,
        'status': 'Delivered',
        'occurred_at': DateTime.utc(2026, 8, 2).toIso8601String(),
        'amount': 9,
        'details_route': '/food',
      },
      {
        'id': 'good-2',
        'profile_id': 'user-1',
        'service_id': 'grocery',
        'title': 'Grocery order',
        'subtitle': null,
        'status': 'Delivered',
        'occurred_at': DateTime.utc(2026, 8, 3).toIso8601String(),
        'amount': 20,
        'details_route': '/grocery',
      },
    ];

    final httpClient = MockClient((request) async {
      return http.Response(
        jsonEncode(rows),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = await _signedInClient(
      userId: 'user-1',
      httpClient: httpClient,
    );
    final repository = SupabaseActivityRepository(client: client);

    final items = await repository.fetchActivities();

    expect(items.map((item) => item.id), ['good-1', 'good-2']);
  });

  test('fetchActivities returns an empty list (not an error) when every row is '
      'malformed', () async {
    final rows = [
      {
        'id': 'bad-1',
        'profile_id': 'user-1',
        'service_id': 'food',
        'title': '',
        'subtitle': null,
        'status': 'Delivered',
        'occurred_at': DateTime.utc(2026, 8, 2).toIso8601String(),
        'amount': 9,
        'details_route': '/food',
      },
    ];

    final httpClient = MockClient((request) async {
      return http.Response(
        jsonEncode(rows),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = await _signedInClient(
      userId: 'user-1',
      httpClient: httpClient,
    );
    final repository = SupabaseActivityRepository(client: client);

    final items = await repository.fetchActivities();

    expect(items, isEmpty);
  });
}
