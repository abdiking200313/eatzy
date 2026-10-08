import 'dart:async';

import '../../services/food/data/category_repository.dart';
import '../../services/food/data/restaurant_menu_repository.dart';
import '../../services/food/data/restaurant_repository.dart';
import '../../services/food/models/category.dart';
import '../../services/food/models/restaurant.dart';
import '../../services/food/models/restaurant_menu.dart';
import '../discovery/store_listing.dart';
import '../discovery/store_listing_repository.dart';
import 'query_cache.dart';

/// The food home screen's unfiltered data: category chips plus the default
/// restaurant list.
typedef FoodHomeData = ({
  List<Category> categories,
  List<Restaurant> restaurants,
});

/// The cached catalog reads behind the most-visited screens. Each getter
/// builds a cheap [CachedQuery] handle; the cached data itself lives in
/// [QueryCache.instance], so every handle for the same key shares it.
///
/// Repositories are constructed inside `load`, never eagerly, so building a
/// handle (or calling `peek`) never touches `Supabase.instance`.
abstract final class CatalogQueries {
  /// Number of restaurant menus [prefetchMenus] warms after the food home
  /// list loads — the ones a user is most likely to tap first.
  static const int menuPrefetchCount = 5;

  /// Super-app home "Popular Stores".
  static CachedQuery<List<StoreListing>> homeStores() => CachedQuery(
    key: 'home_stores',
    load: () async {
      final stores = await StoreListingRepository().fetchStores(limit: 10);
      // StoreListingRepository swallows per-vertical failures into an empty
      // list, so an empty result usually means "offline" — throw instead of
      // overwriting a good cached list with nothing.
      if (stores.isEmpty) throw StateError('No stores loaded');
      return stores;
    },
    encode: (stores) => [for (final store in stores) store.toMap()],
    decode: (json) => [
      for (final row in json as List)
        StoreListing.fromMap(Map<String, dynamic>.from(row as Map)),
    ],
  );

  static CachedQuery<FoodHomeData> foodHome() => CachedQuery(
    key: 'food_home',
    load: () async {
      final (categories, restaurants) = await (
        CategoryRepository().fetchCategories(),
        RestaurantRepository().fetchRestaurants(),
      ).wait;
      return (categories: categories, restaurants: restaurants);
    },
    encode: (data) => {
      'categories': [for (final c in data.categories) c.toMap()],
      'restaurants': [for (final r in data.restaurants) r.toMap()],
    },
    decode: (json) {
      final map = json as Map;
      return (
        categories: [
          for (final row in map['categories'] as List)
            Category.fromMap(Map<String, dynamic>.from(row as Map)),
        ],
        restaurants: [
          for (final row in map['restaurants'] as List)
            Restaurant.fromMap(Map<String, dynamic>.from(row as Map)),
        ],
      );
    },
  );

  /// A restaurant's menu. Shown instantly from cache but, because it carries
  /// prices, refreshed in the background on every open ([Duration.zero])
  /// rather than trusted for the usual five minutes. The order RPC still
  /// recomputes prices server-side either way.
  static CachedQuery<RestaurantMenu> restaurantMenu(String restaurantId) =>
      CachedQuery(
        key: 'restaurant_menu:$restaurantId',
        maxAge: Duration.zero,
        load: () => RestaurantMenuRepository().fetchMenu(restaurantId),
        encode: (menu) => menu.toMap(),
        decode: (json) =>
            RestaurantMenu.fromMap(Map<String, dynamic>.from(json as Map)),
      );

  /// Warms the data the first screens need. Called at startup without
  /// awaiting, so it overlaps the rest of startup instead of delaying it.
  static Future<void> prefetchHome() async {
    await Future.wait([homeStores().prefetch(), foodHome().prefetch()]);
  }

  /// Warms the menus of the first few [restaurants] that have never been
  /// cached, so the first tap opens a full menu. Already-cached menus are
  /// skipped: those render instantly anyway and refresh when opened.
  static void prefetchMenus(Iterable<Restaurant> restaurants) {
    for (final restaurant in restaurants.take(menuPrefetchCount)) {
      final query = restaurantMenu(restaurant.id);
      if (query.peek() == null) unawaited(query.prefetch());
    }
  }
}
