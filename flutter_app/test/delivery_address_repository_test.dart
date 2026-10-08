import 'dart:convert';

import 'package:chowflow/features/addresses/data/delivery_address_repository.dart';
import 'package:chowflow/features/addresses/models/delivery_address.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same technique as activity_repository_test.dart / auth_service_test.dart: a
// real SupabaseClient wired to an http.testing.MockClient, so these tests
// exercise the actual PostgREST request/response path (fluent query builder
// included) without a network call, rather than mocking SupabaseClient's
// internals directly.
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
  group('DeliveryAddress.fromMap', () {
    test('parses a complete row', () {
      final address = DeliveryAddress.fromMap({
        'id': 'addr-1',
        'label': 'Home',
        'recipient_name': 'Asha Ali',
        'phone': '+252 61 234 5678',
        'street': 'Taleex Road, blue gate',
        'district': 'Hodan',
        'city': 'Mogadishu',
        'is_default': true,
        'created_at': DateTime.utc(2026, 9, 1).toIso8601String(),
        'updated_at': DateTime.utc(2026, 9, 2).toIso8601String(),
      });

      expect(address.id, 'addr-1');
      expect(address.label, 'Home');
      expect(address.recipientName, 'Asha Ali');
      expect(address.phone, '+252 61 234 5678');
      expect(address.street, 'Taleex Road, blue gate');
      expect(address.district, 'Hodan');
      expect(address.city, 'Mogadishu');
      expect(address.isDefault, isTrue);
    });

    test('a null label parses to null, not a throw', () {
      final address = DeliveryAddress.fromMap({
        'id': 'addr-1',
        'label': null,
        'recipient_name': 'Asha Ali',
        'phone': '+252 61 234 5678',
        'street': 'Taleex Road, blue gate',
        'district': 'Hodan',
        'city': 'Mogadishu',
        'is_default': false,
        'created_at': DateTime.utc(2026, 9, 1).toIso8601String(),
        'updated_at': DateTime.utc(2026, 9, 1).toIso8601String(),
      });

      expect(address.label, isNull);
      expect(address.isDefault, isFalse);
    });

    test('throws when a required field is missing', () {
      expect(
        () => DeliveryAddress.fromMap({
          'id': 'addr-1',
          'recipient_name': '',
          'phone': '+252 61 234 5678',
          'street': 'Taleex Road, blue gate',
          'district': 'Hodan',
          'city': 'Mogadishu',
          'is_default': false,
          'created_at': DateTime.utc(2026, 9, 1).toIso8601String(),
          'updated_at': DateTime.utc(2026, 9, 1).toIso8601String(),
        }),
        throwsFormatException,
      );
    });
  });

  group('NewDeliveryAddress.toMap', () {
    test('trims text fields and normalizes a blank label to null', () {
      const address = NewDeliveryAddress(
        label: '  ',
        recipientName: ' Asha Ali ',
        phone: ' +252 61 234 5678 ',
        street: ' Taleex Road ',
        district: ' Hodan ',
        city: ' Mogadishu ',
      );

      final map = address.toMap();

      expect(map['label'], isNull);
      expect(map['recipient_name'], 'Asha Ali');
      expect(map['phone'], '+252 61 234 5678');
      expect(map['street'], 'Taleex Road');
      expect(map['district'], 'Hodan');
      expect(map['city'], 'Mogadishu');
      expect(map['is_default'], isFalse);
    });
  });

  group('SupabaseDeliveryAddressRepository', () {
    test(
      'fetchSavedAddresses skips a malformed row and returns the rest',
      () async {
        final rows = [
          {
            'id': 'addr-good',
            'label': 'Home',
            'recipient_name': 'Asha Ali',
            'phone': '+252 61 234 5678',
            'street': 'Taleex Road',
            'district': 'Hodan',
            'city': 'Mogadishu',
            'is_default': true,
            'created_at': DateTime.utc(2026, 9, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 9, 1).toIso8601String(),
          },
          // Malformed: recipient_name blank, which throws inside
          // DeliveryAddress.fromMap. This row must be skipped, not blank
          // the whole list -- mirrors SupabaseActivityRepository's handling
          // of a malformed customer_activity row (issue #62).
          {
            'id': 'addr-bad',
            'label': null,
            'recipient_name': '',
            'phone': '+252 61 234 5678',
            'street': 'Airport Road',
            'district': 'Wadajir',
            'city': 'Mogadishu',
            'is_default': false,
            'created_at': DateTime.utc(2026, 9, 2).toIso8601String(),
            'updated_at': DateTime.utc(2026, 9, 2).toIso8601String(),
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
        final repository = SupabaseDeliveryAddressRepository(client: client);

        final addresses = await repository.fetchSavedAddresses();

        expect(addresses.map((address) => address.id), ['addr-good']);
      },
    );

    test('fetchSavedAddresses throws when no one is signed in', () async {
      final httpClient = MockClient((request) async {
        throw StateError('No request should be made without a session.');
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: _testAuthOptions,
        httpClient: httpClient,
      );
      final repository = SupabaseDeliveryAddressRepository(client: client);

      expect(() => repository.fetchSavedAddresses(), throwsStateError);
    });

    test(
      'create posts the new address and parses the inserted row back',
      () async {
        http.Request? capturedRequest;
        final httpClient = MockClient((request) async {
          capturedRequest = request;
          final created = {
            'id': 'addr-new',
            'label': 'Work',
            'recipient_name': 'Asha Ali',
            'phone': '+252 61 234 5678',
            'street': 'Airport Road',
            'district': 'Wadajir',
            'city': 'Mogadishu',
            'is_default': false,
            'created_at': DateTime.utc(2026, 9, 3).toIso8601String(),
            'updated_at': DateTime.utc(2026, 9, 3).toIso8601String(),
          };
          return http.Response(
            jsonEncode(created),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        });
        final client = await _signedInClient(
          userId: 'user-1',
          httpClient: httpClient,
        );
        final repository = SupabaseDeliveryAddressRepository(client: client);

        final created = await repository.create(
          const NewDeliveryAddress(
            label: 'Work',
            recipientName: 'Asha Ali',
            phone: '+252 61 234 5678',
            street: 'Airport Road',
            district: 'Wadajir',
            city: 'Mogadishu',
          ),
        );

        expect(created.id, 'addr-new');
        expect(created.label, 'Work');
        final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(body['profile_id'], 'user-1');
        expect(body['recipient_name'], 'Asha Ali');
      },
    );
  });
}
