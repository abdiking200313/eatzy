import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/catalog/models/merchant_catalog_item.dart';
import 'package:merchant_app/features/catalog/presentation/merchant_catalog_controller.dart';
import 'package:merchant_app/features/store/models/merchant_vertical.dart';

import 'fakes/fake_merchant_repositories.dart';

// Unit-tests `MerchantCatalogController`'s CRUD + availability-toggle
// bookkeeping (issue #133) against the fake repository.
void main() {
  const item = MerchantCatalogItem(
    id: 'item-1',
    storeId: 'store-1',
    vertical: MerchantVertical.food,
    name: 'Sambusa',
    priceCents: 250,
    isAvailable: true,
  );

  group('load', () {
    test('populates items and hasLoaded on success', () async {
      final controller = MerchantCatalogController(
        repository: FakeMerchantCatalogRepository(initialItems: [item]),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      expect(controller.hasLoaded, isFalse);
      await controller.load();

      expect(controller.hasLoaded, isTrue);
      expect(controller.items, [item]);
      expect(controller.loadError, isNull);
    });

    test('hasLoaded is true with an empty catalog', () async {
      final controller = MerchantCatalogController(
        repository: FakeMerchantCatalogRepository(),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      await controller.load();

      expect(controller.hasLoaded, isTrue);
      expect(controller.items, isEmpty);
    });

    test('sets loadError on failure', () async {
      final repository = FakeMerchantCatalogRepository()
        ..failureToThrow = Exception('network down');
      final controller = MerchantCatalogController(
        repository: repository,
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      await controller.load();

      expect(controller.loadError, isNotNull);
      expect(controller.items, isEmpty);
    });

    test('also loads pharmacy categories for the pharmacy vertical', () async {
      final controller = MerchantCatalogController(
        repository: FakeMerchantCatalogRepository(
          categories: const [PharmacyCategory(id: 'otc', name: 'OTC')],
        ),
        vertical: MerchantVertical.pharmacy,
        storeId: 'pharmacy-1',
      );

      await controller.load();

      expect(controller.pharmacyCategories, hasLength(1));
      expect(controller.pharmacyCategories.first.id, 'otc');
    });
  });

  group('createItem', () {
    test('adds the created item to the list', () async {
      final controller = MerchantCatalogController(
        repository: FakeMerchantCatalogRepository(),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      final succeeded = await controller.createItem(item);

      expect(succeeded, isTrue);
      expect(controller.items, hasLength(1));
      expect(controller.items.first.name, 'Sambusa');
    });

    test('returns false and sets saveError on failure', () async {
      final repository = FakeMerchantCatalogRepository()
        ..failureToThrow = Exception('insert failed');
      final controller = MerchantCatalogController(
        repository: repository,
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      final succeeded = await controller.createItem(item);

      expect(succeeded, isFalse);
      expect(controller.items, isEmpty);
      expect(controller.saveError, isNotNull);
    });
  });

  group('deleteItem', () {
    test('removes the item from the list', () async {
      final controller = MerchantCatalogController(
        repository: FakeMerchantCatalogRepository(initialItems: [item]),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );
      await controller.load();

      final succeeded = await controller.deleteItem(item);

      expect(succeeded, isTrue);
      expect(controller.items, isEmpty);
    });
  });

  group('toggleAvailability', () {
    test('flips isAvailable on the matching item', () async {
      final controller = MerchantCatalogController(
        repository: FakeMerchantCatalogRepository(initialItems: [item]),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );
      await controller.load();

      final succeeded = await controller.toggleAvailability(item);

      expect(succeeded, isTrue);
      expect(controller.items.single.isAvailable, isFalse);
    });
  });
}
