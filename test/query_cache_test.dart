import 'dart:async';
import 'dart:convert';

import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/cache/query_cache.dart';
import 'package:chowflow/platform/discovery/store_listing.dart';
import 'package:chowflow/services/food/models/restaurant.dart';
import 'package:chowflow/services/food/models/restaurant_menu.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements QueryCacheStorage {
  final values = <String, String>{};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String json) async => values[key] = json;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  late _MemoryStorage storage;
  late DateTime now;
  late QueryCache cache;

  setUp(() {
    storage = _MemoryStorage();
    now = DateTime(2026, 9, 26, 12);
    cache = QueryCache(storage: storage, clock: () => now);
  });

  CachedQuery<List<String>> query({
    required Future<List<String>> Function() load,
    String key = 'names',
    Duration maxAge = const Duration(minutes: 5),
  }) => CachedQuery(
    key: key,
    load: load,
    encode: (names) => names,
    decode: (json) => (json as List).cast<String>(),
    maxAge: maxAge,
    cache: cache,
  );

  test('first load has nothing cached, then emits the loaded value', () async {
    final names = query(load: () async => ['a']);

    expect(names.peek(), isNull);
    expect(await names.watch().toList(), [
      ['a'],
    ]);
    expect(names.peek(), ['a']);
  });

  test('a fresh cached value is emitted without hitting the network', () async {
    var loads = 0;
    final names = query(load: () async => ['v${++loads}']);
    await names.refresh();

    expect(await names.watch().toList(), [
      ['v1'],
    ]);
    expect(loads, 1);
  });

  test(
    'a stale cached value is emitted first, then the refreshed one',
    () async {
      var loads = 0;
      final names = query(load: () async => ['v${++loads}']);
      await names.refresh();
      now = now.add(const Duration(minutes: 6));

      expect(await names.watch().toList(), [
        ['v1'],
        ['v2'],
      ]);
    },
  );

  test(
    'a failed refresh keeps showing cached data instead of erroring',
    () async {
      var fail = false;
      final names = query(
        load: () async => fail ? throw Exception('offline') : ['cached'],
        maxAge: Duration.zero,
      );
      await names.refresh();
      fail = true;

      expect(await names.watch().toList(), [
        ['cached'],
      ]);
    },
  );

  test('a failed load with nothing cached surfaces the error', () {
    final names = query(load: () async => throw Exception('offline'));

    expect(names.watch().toList(), throwsException);
  });

  test('concurrent loads of the same key share one request', () async {
    var loads = 0;
    final gate = Completer<void>();
    final names = query(
      load: () async {
        loads++;
        await gate.future;
        return ['a'];
      },
    );

    final prefetch = names.prefetch();
    final watched = names.watch().toList();
    gate.complete();
    await prefetch;

    expect(await watched, [
      ['a'],
    ]);
    expect(loads, 1);
  });

  test('prefetch swallows errors', () async {
    final names = query(load: () async => throw Exception('offline'));

    await expectLater(names.prefetch(), completes);
  });

  test('entries persist to storage and hydrate into a new cache', () async {
    await query(load: () async => ['saved']).refresh();
    await pumpEventQueue();

    cache = QueryCache(storage: storage, clock: () => now);
    await cache.hydrate();

    expect(query(load: () async => []).peek(), ['saved']);
  });

  test('hydrate drops expired and corrupt entries', () async {
    final old = now.subtract(QueryCache.maxDiskAge + const Duration(days: 1));
    storage.values['old'] = jsonEncode({
      't': old.millisecondsSinceEpoch,
      'v': ['x'],
    });
    storage.values['corrupt'] = 'not json';

    await cache.hydrate();
    await pumpEventQueue();

    expect(cache.contains('old'), isFalse);
    expect(cache.contains('corrupt'), isFalse);
    expect(storage.values, isEmpty);
  });

  test('evicts the oldest entries past maxEntries', () async {
    for (var i = 0; i <= QueryCache.maxEntries; i++) {
      await query(key: 'k$i', load: () async => ['$i']).refresh();
    }
    await pumpEventQueue();

    expect(cache.contains('k0'), isFalse);
    expect(cache.contains('k${QueryCache.maxEntries}'), isTrue);
    expect(storage.values.containsKey('k0'), isFalse);
  });

  test('a value that no longer decodes is treated as a cache miss', () async {
    await query(load: () async => ['a']).refresh();
    final broken = CachedQuery<int>(
      key: 'names',
      load: () async => 1,
      encode: (value) => value,
      decode: (json) => json as int,
      cache: cache,
    );

    expect(broken.peek(), isNull);
  });

  group('model round-trips through JSON', () {
    Object? roundTrip(Object? value) => jsonDecode(jsonEncode(value));

    test('StoreListing', () {
      const store = StoreListing(
        id: 's1',
        serviceId: ServiceId.pharmacy,
        name: 'Care',
        subtitle: 'Main St',
        imageUrl: null,
        route: '/pharmacy/s1',
      );
      final copy = StoreListing.fromMap(
        roundTrip(store.toMap()) as Map<String, dynamic>,
      );

      expect(copy.toMap(), store.toMap());
    });

    test('RestaurantMenu', () {
      const menu = RestaurantMenu(
        restaurant: Restaurant(
          id: 'r1',
          name: 'Pasta',
          description: 'Fresh',
          logoUrl: 'logo.png',
        ),
        categories: [
          MenuCategory(
            id: 'c1',
            name: 'Mains',
            items: [
              MenuItem(
                id: 'm1',
                name: 'Carbonara',
                description: 'Classic',
                price: 1250,
                imageUrl: 'img.png',
                categoryId: 'c1',
              ),
            ],
          ),
        ],
      );
      final copy = RestaurantMenu.fromMap(
        roundTrip(menu.toMap()) as Map<String, dynamic>,
      );

      expect(copy.toMap(), menu.toMap());
      expect(copy.categories.single.items.single.price, 1250);
    });
  });
}
