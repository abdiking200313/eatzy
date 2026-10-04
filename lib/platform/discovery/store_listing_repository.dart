import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/service_module.dart';
import '../../services/food/data/restaurant_repository.dart';
import '../../services/food/models/restaurant.dart';
import '../../services/grocery/data/grocery_repository.dart';
import '../../services/grocery/models/grocery_models.dart';
import '../../services/pharmacy/data/pharmacy_repository.dart';
import '../../services/pharmacy/models/pharmacy_store.dart';
import '../error_reporting/error_reporter.dart';
import 'store_listing.dart';

/// Thrown by [StoreListingRepository.fetchStores] when every vertical it
/// queried failed and there is nothing to show at all (e.g. Supabase is
/// unreachable). Deliberately carries no raw exception detail -- the
/// underlying error for each vertical is already reported individually
/// through [ErrorReporting] before this is thrown -- so [toString] is always
/// safe to surface directly in the UI (e.g. an error state with a Retry
/// action), matching the `describeAuthError`-style sanitization used
/// elsewhere in this app.
///
/// When only *some* verticals fail, [fetchStores] does not throw: it quietly
/// returns the stores from whichever verticals did load, same as before —
/// only the all-failed case is now distinguishable from "every vertical
/// genuinely has nothing to show".
class StoreListingUnavailableException implements Exception {
  const StoreListingUnavailableException();

  @override
  String toString() =>
      'Stores could not be loaded. Please check your connection and try '
      'again.';
}

/// One vertical's fetch outcome: either the stores it loaded, or an empty
/// list because it failed (the failure itself was already reported).
class _VerticalFetch {
  const _VerticalFetch({required this.stores, required this.failed});

  final List<StoreListing> stores;
  final bool failed;
}

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
  ///
  /// Each vertical's failure is reported individually through
  /// [ErrorReporting] rather than silently swallowed. When at least one
  /// vertical (of the ones [filter] asked for) succeeds, this returns
  /// whatever loaded, same as before a partial failure. Only when every
  /// requested vertical fails does this throw
  /// [StoreListingUnavailableException], so a real outage is distinguishable
  /// from every vertical genuinely having nothing to show.
  Future<List<StoreListing>> fetchStores({
    ServiceId? filter,
    int? limit,
  }) async {
    final List<StoreListing> listings;
    if (filter == null) {
      final results = await Future.wait<_VerticalFetch>([
        _fetchFood(),
        _fetchGrocery(),
        _fetchPharmacy(),
      ]);
      if (results.every((result) => result.failed)) {
        throw const StoreListingUnavailableException();
      }
      listings = _interleave([for (final result in results) result.stores]);
    } else {
      final result = switch (filter) {
        ServiceId.food => await _fetchFood(),
        ServiceId.grocery => await _fetchGrocery(),
        ServiceId.pharmacy => await _fetchPharmacy(),
        ServiceId.unknown => const _VerticalFetch(stores: [], failed: false),
      };
      if (result.failed) {
        throw const StoreListingUnavailableException();
      }
      listings = result.stores;
    }

    if (limit == null || listings.length <= limit) {
      return listings;
    }
    return listings.sublist(0, limit);
  }

  Future<_VerticalFetch> _fetchFood() async {
    try {
      final restaurants = await _restaurantRepository.fetchRestaurants();
      return _VerticalFetch(
        stores: restaurants.map(_fromRestaurant).toList(growable: false),
        failed: false,
      );
    } catch (error, stackTrace) {
      ErrorReporting.instance.reportError(
        error,
        stackTrace,
        context: 'StoreListingRepository._fetchFood',
      );
      return const _VerticalFetch(stores: [], failed: true);
    }
  }

  Future<_VerticalFetch> _fetchGrocery() async {
    try {
      final stores = await _groceryRepository.fetchStores();
      return _VerticalFetch(
        stores: stores.map(_fromGroceryStore).toList(growable: false),
        failed: false,
      );
    } catch (error, stackTrace) {
      ErrorReporting.instance.reportError(
        error,
        stackTrace,
        context: 'StoreListingRepository._fetchGrocery',
      );
      return const _VerticalFetch(stores: [], failed: true);
    }
  }

  Future<_VerticalFetch> _fetchPharmacy() async {
    try {
      final stores = await _pharmacyRepository.fetchStores();
      return _VerticalFetch(
        stores: stores.map(_fromPharmacyStore).toList(growable: false),
        failed: false,
      );
    } catch (error, stackTrace) {
      ErrorReporting.instance.reportError(
        error,
        stackTrace,
        context: 'StoreListingRepository._fetchPharmacy',
      );
      return const _VerticalFetch(stores: [], failed: true);
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
