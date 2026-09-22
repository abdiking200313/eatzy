import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/platform/discovery/store_listing.dart';
import 'package:chowflow/screens/explore.dart';
import 'package:chowflow/services/food/data/category_repository.dart';
import 'package:chowflow/services/food/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test seam for `ExploreScreen.categoryRepository` -- `implements` (not
/// `extends`) so the default constructor never runs and never touches
/// `Supabase.instance.client`, matching the pattern
/// `test/food_explore_screen_test.dart` uses for `RestaurantRepository`.
class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this._categories);

  final List<Category> _categories;

  @override
  Future<List<Category>> fetchCategories({
    int limit = CategoryRepository.defaultPageSize,
    int offset = 0,
  }) async => _categories;
}

const _sampleStores = [
  StoreListing(
    id: 'restaurant-1',
    serviceId: ServiceId.food,
    name: 'Mogadishu Kitchen',
    subtitle: 'Somali favourites',
    imageUrl: null,
    route: '/food/restaurant/restaurant-1',
  ),
  // No imageUrl (null) for every fixture here, deliberately: a real network
  // image would leave CachedNetworkImage's retry/backoff timers running and
  // make `pumpAndSettle` hang -- the "No picture available" placeholder path
  // is covered directly by `test/store_list_card_test.dart` instead.
  StoreListing(
    id: 'grocery-1',
    serviceId: ServiceId.grocery,
    name: 'Bakaara Mart',
    subtitle: 'Bakaara',
    imageUrl: null,
    route: '/grocery/store/grocery-1',
  ),
  StoreListing(
    id: 'pharmacy-1',
    serviceId: ServiceId.pharmacy,
    name: 'Hodan Pharmacy',
    subtitle: 'Hodan',
    imageUrl: null,
    route: '/pharmacy/store/pharmacy-1',
  ),
];

/// Mirrors `StoreListingRepository.fetchStores`'s filter contract closely
/// enough for these tests: `null` returns everything, otherwise only that
/// vertical's stores.
Future<List<StoreListing>> _loadStores(ServiceId? filter) async {
  if (filter == null) {
    return _sampleStores;
  }
  return _sampleStores.where((store) => store.serviceId == filter).toList();
}

void main() {
  testWidgets('explore lists stores from every vertical', (tester) async {
    // Tall enough that all three fixture store cards render without needing
    // to scroll the (lazily built) feed list.
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ExploreScreen(
          storeListingLoader: _loadStores,
          categoryRepository: _FakeCategoryRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
    for (final label in ['All', 'Food', 'Grocery', 'Pharmacy']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final store in _sampleStores) {
      expect(find.text(store.name), findsOneWidget);
    }
  });

  testWidgets('explore stays overflow-free on a narrow, large-text screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: ExploreScreen(
            storeListingLoader: _loadStores,
            categoryRepository: _FakeCategoryRepository(const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a service filter chip narrows the store feed', (
    tester,
  ) async {
    // Tall enough that all three fixture store cards render without needing
    // to scroll the (lazily built) feed list.
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ExploreScreen(
          storeListingLoader: _loadStores,
          categoryRepository: _FakeCategoryRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // All three verticals show up unfiltered.
    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Bakaara Mart'), findsOneWidget);
    expect(find.text('Hodan Pharmacy'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Bakaara Mart'), findsNothing);
    expect(find.text('Hodan Pharmacy'), findsNothing);

    // Switching back to All restores the full feed.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Bakaara Mart'), findsOneWidget);
    expect(find.text('Hodan Pharmacy'), findsOneWidget);
  });
}
