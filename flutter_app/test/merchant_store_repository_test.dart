import 'dart:convert';

import 'package:chowflow/features/merchant/store/data/merchant_store_repository.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Guards the merchant store queries against the *live* column names. The
// merchant screens were first written against the stale `supabase/schema.sql`
// (`restaurants.image_url`), but the live `restaurants` table stores its
// picture in `logo_url` -- selecting the wrong column made PostgREST reject
// the query, so "My Store" always showed "Your store could not be loaded".
void main() {
  late List<http.Request> requests;

  SupabaseMerchantStoreRepository repository(
    Object? Function(http.Request request) respond,
  ) {
    requests = [];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(respond(request)),
          200,
          request: request,
        );
      }),
    );
    return SupabaseMerchantStoreRepository(client: client);
  }

  test('the food lookup selects the live restaurants columns', () async {
    final repo = repository((_) => null);

    expect(await repo.fetchOwnStore('owner-1'), isNull);

    final food = requests.firstWhere(
      (r) => r.url.path == '/rest/v1/restaurants',
    );
    final columns = food.url.queryParameters['select']!.split(',');
    expect(columns, containsAll(['id', 'name', 'address', 'is_open']));
    expect(columns, contains('description'));
    expect(columns, contains('logo_url'));
    expect(columns, isNot(contains('image_url')));
  });

  test('a food store maps logo_url to imageUrl', () async {
    final repo = repository(
      (request) => request.url.path == '/rest/v1/restaurants'
          ? {
              'id': 'r-1',
              'name': 'Zivo Grill',
              'address': 'Hodan',
              'is_open': true,
              'description': 'Grills',
              'logo_url': 'https://example.com/logo.png',
            }
          : null,
    );

    final store = await repo.fetchOwnStore('owner-1');

    expect(store!.vertical, MerchantVertical.food);
    expect(store.imageUrl, 'https://example.com/logo.png');
    expect(store.location, 'Hodan');
  });

  test('updating a food store writes logo_url, not image_url', () async {
    final repo = repository(
      (_) => {
        'id': 'r-1',
        'name': 'Zivo Grill',
        'address': 'Hodan',
        'is_open': true,
        'description': null,
        'logo_url': 'https://example.com/new.png',
      },
    );
    final store = (await repo.fetchOwnStore('owner-1'))!;
    requests.clear();

    await repo.updateStore(
      store,
      ownerId: 'owner-1',
      name: 'Zivo Grill',
      location: 'Hodan',
      isOpen: true,
      imageUrl: 'https://example.com/new.png',
    );

    final patch = requests.firstWhere((r) => r.method == 'PATCH');
    final body = jsonDecode(patch.body) as Map<String, dynamic>;
    expect(body['logo_url'], 'https://example.com/new.png');
    expect(body.containsKey('image_url'), isFalse);
  });
}
