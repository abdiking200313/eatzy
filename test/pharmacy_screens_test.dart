import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  testWidgets('pharmacy catalog clearly explains the OTC-only scope', (
    tester,
  ) async {
    final controller = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: ActivityController(),
      storage: MemoryCartStorage<PharmacyCartItem>(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyCatalogScreen(
          storeId: SeededPharmacyRepository.defaultStoreId,
          storeName: 'Pharmacy',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pharmacy'), findsOneWidget);
    expect(find.text('Over-the-counter (OTC) only'), findsOneWidget);
    expect(
      find.textContaining('does not accept prescriptions'),
      findsOneWidget,
    );
    expect(find.text('Paracetamol'), findsOneWidget);
    // The store search field's `TextField` carries its own internal
    // `Scrollable`, so the default `find.byType(Scrollable)` now matches
    // more than one widget — pin `scrollUntilVisible` to the catalog list
    // itself, same as `cart_checkout_visual_consistency_test.dart` does.
    await tester.scrollUntilVisible(
      find.text('Out of stock'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('pulling to refresh reloads the pharmacy catalog', (
    tester,
  ) async {
    final repository = _CountingPharmacyRepository();
    final controller = PharmacyController(
      repository: repository,
      activityController: ActivityController(),
      storage: MemoryCartStorage<PharmacyCartItem>(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyCatalogScreen(
          storeId: SeededPharmacyRepository.defaultStoreId,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
  });

  testWidgets('typing a search term narrows this pharmacy\'s catalog', (
    tester,
  ) async {
    final controller = PharmacyController(
      repository: _MultiStorePharmacyRepository(),
      activityController: ActivityController(),
      storage: MemoryCartStorage<PharmacyCartItem>(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyCatalogScreen(storeId: 'store-a', controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vitamin A'), findsOneWidget);
    expect(find.text('Bandages A'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Vitamin');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin A'), findsOneWidget);
    expect(find.text('Bandages A'), findsNothing);
  });

  testWidgets(
    'adding a product from a different pharmacy prompts to replace the cart',
    (tester) async {
      final controller = PharmacyController(
        repository: _MultiStorePharmacyRepository(),
        activityController: ActivityController(),
        storage: MemoryCartStorage<PharmacyCartItem>(),
      );
      await controller.loadProducts(storeId: 'store-a');
      controller.addProduct(controller.products.first);
      expect(controller.cartItems.single.product.storeId, 'store-a');

      await tester.pumpWidget(
        MaterialApp(
          home: PharmacyCatalogScreen(
            storeId: 'store-b',
            storeName: 'Store B',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-pharmacy-store-b-item')));
      await tester.pumpAndSettle();

      expect(find.text('Start a new pharmacy cart?'), findsOneWidget);

      await tester.tap(find.text('Start new cart'));
      await tester.pumpAndSettle();

      expect(controller.cartItems.single.product.storeId, 'store-b');
      expect(find.text('Store B item added to pharmacy cart.'), findsOneWidget);
    },
  );
}

/// A [PharmacyRepository] fake backing two distinct pharmacies, used to
/// exercise store-scoping and the cross-pharmacy cart-conflict prompt.
class _MultiStorePharmacyRepository implements PharmacyRepository {
  static const _products = <PharmacyProduct>[
    PharmacyProduct(
      id: 'store-a-vitamin',
      storeId: 'store-a',
      name: 'Vitamin A',
      description: 'Store A vitamin.',
      category: 'Vitamins',
      unitPrice: 3,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'store-a-bandages',
      storeId: 'store-a',
      name: 'Bandages A',
      description: 'Store A first aid.',
      category: 'First aid',
      unitPrice: 2,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'store-b-item',
      storeId: 'store-b',
      name: 'Store B item',
      description: 'Store B essential.',
      category: 'Wellness',
      unitPrice: 5,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
  ];

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async {
    final query = searchQuery?.trim().toLowerCase();
    final hasSearch = query != null && query.isNotEmpty;
    final matches = _products
        .where((product) => product.storeId == storeId)
        .where(
          (product) => !hasSearch || product.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
    if (offset >= matches.length) {
      return const [];
    }
    final end = (offset + limit).clamp(0, matches.length);
    return List<PharmacyProduct>.unmodifiable(matches.sublist(offset, end));
  }
}

class _CountingPharmacyRepository implements PharmacyRepository {
  int fetchCount = 0;

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async {
    fetchCount++;
    return const SeededPharmacyRepository().fetchProducts(
      storeId: storeId,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }
}
