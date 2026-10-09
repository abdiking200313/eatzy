import 'package:chowflow/app/app_services.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/app_scope_test_helpers.dart';

/// Covers [AppServices.groceryController]/[AppServices.pharmacyController]:
/// unlike a lazy-initializer static singleton (which reads
/// `Supabase.instance.client` directly and so is never directly
/// unit-testable), this lazy-build-and-cache logic runs through
/// [AppServices] -- which already takes an injected [SupabaseClient] --
/// making it testable.
void main() {
  setUp(() {
    // `GroceryController`/`PharmacyController` persist their cart via
    // `SharedPreferencesCartStorage`; registering with the session reset
    // registry below triggers a `loadForOwner` read against it.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('AppServices.groceryController', () {
    test('builds lazily and caches one controller per GroceryStoreType', () {
      final appServices = buildTestAppServices();

      final grocery = appServices.groceryController(GroceryStoreType.grocery);
      final groceryAgain = appServices.groceryController(
        GroceryStoreType.grocery,
      );
      final freshMeat = appServices.groceryController(
        GroceryStoreType.freshMeat,
      );

      expect(groceryAgain, same(grocery));
      expect(freshMeat, isNot(same(grocery)));
      expect(grocery.storeType, GroceryStoreType.grocery);
      expect(freshMeat.storeType, GroceryStoreType.freshMeat);
    });

    test('registers with sessionResetRegistry so an account switch reloads '
        'its cart', () {
      final appServices = buildTestAppServices();
      final grocery = appServices.groceryController(GroceryStoreType.grocery);

      appServices.sessionResetRegistry.notifyAll('user-1');

      // `loadForOwner` sets `cartOwnerId` synchronously before its first
      // `await`, so this is observable immediately -- no need to await
      // the fire-and-forget reload itself.
      expect(grocery.cartOwnerId, 'user-1');
    });
  });

  group('AppServices.pharmacyController', () {
    test('builds lazily and caches a single controller', () {
      final appServices = buildTestAppServices();

      final pharmacy = appServices.pharmacyController;
      final pharmacyAgain = appServices.pharmacyController;

      expect(pharmacyAgain, same(pharmacy));
    });

    test('registers with sessionResetRegistry so an account switch reloads '
        'its cart', () {
      final appServices = buildTestAppServices();
      final pharmacy = appServices.pharmacyController;

      appServices.sessionResetRegistry.notifyAll('user-1');

      expect(pharmacy.cartOwnerId, 'user-1');
    });
  });
}
