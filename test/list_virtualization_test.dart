import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/grocery/presentation/grocery_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_store_screen.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_store.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_store_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/controllers.dart';
import 'helpers/memory_cart_storage.dart';

/// Pins issue #61's list-virtualization fix (reverted by the store-scoping
/// refactor in PR #163, restored by issue #177) by exercising it directly:
/// a long list must not build far-offscreen rows just because they exist in
/// the underlying data. Nothing else in `test/` asserts this, which is why
/// the regression made it through two PRs unnoticed — see issue #177.
///
/// Each screen is fed hundreds of rows and checked against the first (must
/// be built — a sanity check that the list actually rendered) and a row
/// deep enough to be far outside any real viewport plus scroll cache extent
/// (must NOT be built — the actual virtualization assertion). A widget not
/// built at all is absent even from an unbuilt-widget search: `find.text`
/// only matches elements that exist in the tree, not merely off-current-
/// screen ones. `pumpAndSettle` is intentionally avoided for the "not
/// built" checks: settling can trigger more layout/scroll passes than a
/// real first frame would, which would only make a virtualization failure
/// harder (not easier) to observe — a single `pump()` mirrors what the
/// first frame actually builds.
void main() {
  group('GroceryScreen (store list)', () {
    testWidgets('does not build store rows far outside the viewport', (
      tester,
    ) async {
      final controller = GroceryController(
        repository: _ManyGroceryStoresRepository(count: 300),
        storage: MemoryCartStorage<GroceryCartLine>(),
      );

      await tester.pumpWidget(
        MaterialApp(home: GroceryScreen(controller: controller)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Store 0'), findsOneWidget);
      expect(find.text('Store 299'), findsNothing);
    });
  });

  group('GroceryStoreScreen (one store\'s products)', () {
    testWidgets('does not build product rows far outside the viewport', (
      tester,
    ) async {
      const storeId = 'big-store';
      final controller = GroceryController(
        repository: _OneBigGroceryStoreRepository(
          storeId: storeId,
          productCount: 300,
        ),
        storage: MemoryCartStorage<GroceryCartLine>(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GroceryStoreScreen(storeId: storeId, controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Product 0'), findsOneWidget);
      expect(find.text('Product 299'), findsNothing);
    });
  });

  group('PharmacyStoreListScreen', () {
    testWidgets('does not build pharmacy rows far outside the viewport', (
      tester,
    ) async {
      final stores = [
        for (var i = 0; i < 300; i++)
          PharmacyStore(id: 'pharmacy-$i', name: 'Pharmacy $i', address: ''),
      ];
      final controller = buildPharmacyController(
        repository: const _EmptyPharmacyRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PharmacyStoreListScreen(
            storeLoader: () async => stores,
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Pharmacy 0'), findsOneWidget);
      expect(find.text('Pharmacy 299'), findsNothing);
    });
  });
}

class _ManyGroceryStoresRepository implements GroceryRepository {
  const _ManyGroceryStoresRepository({required this.count});

  final int count;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    return [
      for (var i = 0; i < count; i++)
        GroceryStore(
          id: 'store-$i',
          name: 'Store $i',
          area: 'Area $i',
          products: const [],
        ),
    ];
  }
}

class _OneBigGroceryStoreRepository implements GroceryRepository {
  const _OneBigGroceryStoreRepository({
    required this.storeId,
    required this.productCount,
  });

  final String storeId;
  final int productCount;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    return [
      GroceryStore(
        id: storeId,
        name: 'Big Store',
        area: 'Downtown',
        products: [
          for (var i = 0; i < productCount; i++)
            GroceryProduct(
              id: 'product-$i',
              storeId: storeId,
              name: 'Product $i',
              description: 'A product',
              unitPrice: 100,
              pricingUnit: GroceryPricingUnit.each,
              stockState: GroceryStockState.inStock,
              availableQuantity: 5,
              icon: '🛒',
            ),
        ],
      ),
    ];
  }
}

/// An unused fake — this test only needs `PharmacyController` for the cart
/// badge in the app bar; the store list itself comes from `storeLoader`.
class _EmptyPharmacyRepository implements PharmacyRepository {
  const _EmptyPharmacyRepository();

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async => const [];
}
