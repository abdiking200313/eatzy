import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/store/models/merchant_store.dart';
import 'package:merchant_app/features/store/models/merchant_vertical.dart';
import 'package:merchant_app/features/store/presentation/merchant_store_controller.dart';

import 'fakes/fake_merchant_repositories.dart';

// Unit-tests `MerchantStoreController`'s loading/error/empty bookkeeping
// (issue #133), against the fake repository rather than a live Supabase
// project (no network access in this sandbox).
void main() {
  group('load', () {
    test('populates store and hasLoaded on success', () async {
      final store = const MerchantStore(
        id: 'restaurant-1',
        vertical: MerchantVertical.food,
        name: 'Zivo Diner',
        location: '123 Main St',
        isOpen: true,
      );
      final controller = MerchantStoreController(
        repository: FakeMerchantStoreRepository(initialStore: store),
      );

      expect(controller.hasLoaded, isFalse);
      await controller.load('merchant-1');

      expect(controller.hasLoaded, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.loadError, isNull);
      expect(controller.store, store);
    });

    test('hasLoaded is true with a null store (empty state)', () async {
      final controller = MerchantStoreController(
        repository: FakeMerchantStoreRepository(),
      );

      await controller.load('merchant-1');

      expect(controller.hasLoaded, isTrue);
      expect(controller.store, isNull);
      expect(controller.loadError, isNull);
    });

    test('sets loadError and leaves store null on failure', () async {
      final repository = FakeMerchantStoreRepository()
        ..failureToThrow = Exception('network down');
      final controller = MerchantStoreController(repository: repository);

      await controller.load('merchant-1');

      expect(controller.isLoading, isFalse);
      expect(controller.loadError, isNotNull);
      expect(controller.store, isNull);
    });
  });

  group('createStore', () {
    test('sets store and returns true on success', () async {
      final controller = MerchantStoreController(
        repository: FakeMerchantStoreRepository(),
      );

      final succeeded = await controller.createStore(
        vertical: MerchantVertical.grocery,
        ownerId: 'merchant-1',
        name: 'Bakaal Fresh',
        location: 'Hodan',
      );

      expect(succeeded, isTrue);
      expect(controller.store, isNotNull);
      expect(controller.store!.name, 'Bakaal Fresh');
      expect(controller.saveError, isNull);
    });

    test('returns false and sets saveError on failure', () async {
      final repository = FakeMerchantStoreRepository()
        ..failureToThrow = Exception('insert failed');
      final controller = MerchantStoreController(repository: repository);

      final succeeded = await controller.createStore(
        vertical: MerchantVertical.food,
        ownerId: 'merchant-1',
        name: 'Zivo Diner',
        location: '123 Main St',
      );

      expect(succeeded, isFalse);
      expect(controller.store, isNull);
      expect(controller.saveError, isNotNull);
    });
  });

  group('updateStore', () {
    test('returns false with no store loaded', () async {
      final controller = MerchantStoreController(
        repository: FakeMerchantStoreRepository(),
      );

      final succeeded = await controller.updateStore(
        ownerId: 'merchant-1',
        name: 'New name',
        location: 'New location',
        isOpen: false,
      );

      expect(succeeded, isFalse);
    });

    test('updates the loaded store on success', () async {
      final store = const MerchantStore(
        id: 'restaurant-1',
        vertical: MerchantVertical.food,
        name: 'Zivo Diner',
        location: '123 Main St',
        isOpen: true,
      );
      final controller = MerchantStoreController(
        repository: FakeMerchantStoreRepository(initialStore: store),
      );
      await controller.load('merchant-1');

      final succeeded = await controller.updateStore(
        ownerId: 'merchant-1',
        name: 'Zivo Diner 2',
        location: '456 Side St',
        isOpen: false,
      );

      expect(succeeded, isTrue);
      expect(controller.store!.name, 'Zivo Diner 2');
      expect(controller.store!.location, '456 Side St');
      expect(controller.store!.isOpen, isFalse);
    });
  });
}
