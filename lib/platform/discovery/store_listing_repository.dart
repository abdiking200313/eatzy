import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/service_module.dart';
import '../../services/food/data/restaurant_repository.dart';
import '../../services/food/models/restaurant.dart';
import '../../services/grocery/data/grocery_repository.dart';
import '../../services/grocery/models/grocery_models.dart';
import '../../services/pharmacy/data/pharmacy_repository.dart';
import '../../services/pharmacy/models/pharmacy_store.dart';
import 'store_listing.dart';

/// Aggregates `Restaurant`/`GroceryStore`/`PharmacyStore` rows from their own
/// per-vertical repositories into the shared [StoreListing] shape used by
/// the home screen's "Popular Stores" section and the rebuilt Explore tab.
class StoreListingRepository {
  StoreListingRepository({
    RestaurantRepository? restaurantRepository,
    GroceryRepository? groceryRepository,
    PharmacyStoreRepository? pharmacyRepository,
  }) : _restaurantRepository = restaurantRepository ?? RestaurantRepository(),
       _groceryRepository =
           groceryRepository ??
           SupabaseGroceryCatalogRepository(client: Supabase.instance.client),
       _pharmacyRepository =
           pharmacyRepository ??
           SupabasePharmacyStoreRepository(client: Supabase.instance.client);

  final RestaurantRepository _restaurantRepository;
  final GroceryRepository _groceryRepository;
  final PharmacyStoreRepository _pharmacyRepository;

  /// Fetches stores across verticals. [filter] null means all three
  /// verticals mixed together; otherwise only that vertical. [limit] caps
  /// the total returned count (applied after mixing, not per-vertical) —
  /// omit/null means no cap.
  Future<List<StoreListing>> fetchStores({
    ServiceId? filter,
    int? limit,
  }) async {
    final List<StoreListing> listings;
    if (filter == null) {
      final results = await Future.wait<List<StoreListing>>([
        _fetchFood(),
        _fetchGrocery(),
        _fetchPharmacy(),
      ]);
      listings = _interleave(results);
    } else {
      listings = switch (filter) {
        ServiceId.food => await _fetchFood(),
        ServiceId.grocery => await _fetchGrocery(),
        ServiceId.pharmacy => await _fetchPharmacy(),
        ServiceId.unknown => const [],
      };
    }

    if (limit == null || listings.length <= limit) {
      return listings;
    }
    return listings.sublist(0, limit);
  }

  Future<List<StoreListing>> _fetchFood() async {
    try {
      final restaurants = await _restaurantRepository.fetchRestaurants();
      return restaurants.map(_fromRestaurant).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<StoreListing>> _fetchGrocery() async {
    try {
      final stores = await _groceryRepository.fetchStores();
      return stores.map(_fromGroceryStore).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<StoreListing>> _fetchPharmacy() async {
    try {
      final stores = await _pharmacyRepository.fetchStores();
      return stores.map(_fromPharmacyStore).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static StoreListing _fromRestaurant(Restaurant restaurant) {
    return StoreListing(
      id: restaurant.id,
      serviceId: ServiceId.food,
      name: restaurant.name,
      subtitle: restaurant.description,
      imageUrl: restaurant.logoUrl.isEmpty ? null : restaurant.logoUrl,
      route: AppRoutes.restaurantDetails(restaurant.id),
    );
  }

  static StoreListing _fromGroceryStore(GroceryStore store) {
    return StoreListing(
      id: store.id,
      serviceId: ServiceId.grocery,
      name: store.name,
      subtitle: store.area,
      imageUrl: store.imageUrl,
      route: store.storeType.storeDetailsRoute(store.id),
    );
  }

  static StoreListing _fromPharmacyStore(PharmacyStore store) {
    return StoreListing(
      id: store.id,
      serviceId: ServiceId.pharmacy,
      name: store.name,
      subtitle: store.address,
      imageUrl: store.imageUrl,
      route: AppRoutes.pharmacyStoreDetails(store.id),
    );
  }

  /// Round-robins across [lists] (one item from each in turn) rather than
  /// concatenating them, so a mixed "Popular Stores" section doesn't show
  /// every restaurant before the first grocery/pharmacy store just because
  /// of fetch order.
  static List<StoreListing> _interleave(List<List<StoreListing>> lists) {
    final result = <StoreListing>[];
    var index = 0;
    var remaining = lists.fold<int>(0, (sum, list) => sum + list.length);
    while (remaining > 0) {
      for (final list in lists) {
        if (index < list.length) {
          result.add(list[index]);
          remaining--;
        }
      }
      index++;
    }
    return result;
  }
}
