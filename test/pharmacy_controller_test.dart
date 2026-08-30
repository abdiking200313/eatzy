import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_checkout.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  late ActivityController activityController;
  late PharmacyController controller;
  late MemoryCartStorage<PharmacyCartItem> storage;

  setUp(() async {
    activityController = ActivityController();
    storage = MemoryCartStorage<PharmacyCartItem>();
    controller = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: activityController,
      storage: storage,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await controller.loadProducts(
      storeId: SeededPharmacyRepository.defaultStoreId,
    );
  });

  test('pharmacy cart adds, adjusts, removes, and calculates USD totals', () {
    final paracetamol = controller.products.first;

    expect(controller.addProduct(paracetamol), PharmacyCartAddResult.added);
    expect(
      controller.addProduct(paracetamol),
      PharmacyCartAddResult.quantityIncreased,
    );

    expect(controller.cartItems, hasLength(1));
    expect(controller.itemCount, 2);
    expect(controller.subtotal, 5.50);
    expect(controller.total, 8.00);

    controller.decrement(paracetamol.id);
    expect(controller.cartItems.single.quantity, 1);

    controller.removeProduct(paracetamol.id);
    expect(controller.isCartEmpty, isTrue);
    expect(controller.total, 0);
  });

  test('an unavailable OTC product cannot be added', () {
    final unavailable = controller.products.firstWhere(
      (product) => !product.isAvailable,
    );

    expect(
      controller.addProduct(unavailable),
      PharmacyCartAddResult.unavailable,
    );
    expect(controller.isCartEmpty, isTrue);
  });

  test('a non-OTC product is rejected by the domain controller', () {
    const prescriptionProduct = PharmacyProduct(
      id: 'prescription-only',
      storeId: SeededPharmacyRepository.defaultStoreId,
      name: 'Prescription medicine',
      description: 'Not eligible for the OTC launch.',
      category: 'Prescription',
      unitPrice: 10,
      stockQuantity: 5,
      saleType: PharmacySaleType.prescriptionOnly,
    );

    expect(
      controller.addProduct(prescriptionProduct),
      PharmacyCartAddResult.notOverTheCounter,
    );
    expect(controller.isCartEmpty, isTrue);
  });

  test('checkout validates cart and Somalia delivery details', () {
    const emptyDetails = PharmacyCheckoutDetails(
      customerName: '',
      phoneNumber: '12',
      city: '',
      district: '',
      addressLine: '',
    );

    final validation = controller.validateCheckout(emptyDetails);

    expect(validation.isValid, isFalse);
    expect(validation.errorFor('cart'), isNotNull);
    expect(validation.errorFor('customerName'), isNotNull);
    expect(validation.errorFor('phoneNumber'), isNotNull);
    expect(validation.errorFor('city'), contains('Somalia'));
    expect(validation.errorFor('district'), isNotNull);
    expect(validation.errorFor('addressLine'), isNotNull);
    expect(PharmacyCheckoutDetails.country, 'Somalia');
  });

  test('demo checkout records pharmacy activity and clears its cart', () async {
    controller.addProduct(controller.products.first);
    const details = PharmacyCheckoutDetails(
      customerName: 'Asha Ali',
      phoneNumber: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      addressLine: 'Taleex Road, blue gate',
      deliveryInstructions: 'Please call on arrival.',
    );

    final result = await controller.placeDemoOrder(details);

    expect(result.isSuccess, isTrue);
    expect(result.message, contains('No payment was processed'));
    expect(controller.isCartEmpty, isTrue);
    expect(activityController.items, hasLength(1));
    expect(activityController.items.single.serviceId, ServiceId.pharmacy);
    expect(activityController.items.single.status, 'Demo confirmed');
    expect(activityController.items.single.amount, 5.25);
  });

  test('pharmacy cart survives a simulated app reload', () async {
    await controller.loadForOwner('user-1');
    final paracetamol = controller.products.first;
    controller.addProduct(paracetamol);
    controller.increment(paracetamol.id);
    await controller.pendingCartWrite;

    // Simulate the app restarting: a brand new controller backed by the
    // same underlying storage should restore the persisted cart.
    final restarted = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: activityController,
      storage: storage,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await restarted.loadProducts(
      storeId: SeededPharmacyRepository.defaultStoreId,
    );
    await restarted.loadForOwner('user-1');

    expect(restarted.cartItems, hasLength(1));
    expect(restarted.cartItems.single.product.id, paracetamol.id);
    expect(restarted.cartItems.single.quantity, 2);
  });

  test('switching accounts clears and reloads the pharmacy cart', () async {
    await controller.loadForOwner('user-1');
    final paracetamol = controller.products.first;
    controller.addProduct(paracetamol);
    expect(controller.isCartNotEmpty, isTrue);
    await controller.pendingCartWrite;

    await controller.loadForOwner('user-2');
    expect(controller.isCartEmpty, isTrue);

    final otherProduct = controller.products[1];
    controller.addProduct(otherProduct);
    await controller.pendingCartWrite;
    await controller.loadForOwner('user-1');
    expect(controller.cartItems.single.product.id, paracetamol.id);

    await controller.loadForOwner('user-2');
    expect(controller.cartItems.single.product.id, otherProduct.id);
  });

  test('placeDemoOrder surfaces an error, resets loading, and keeps the cart '
      'when the order repository throws', () async {
    final throwingActivityController = ActivityController();
    final throwingController = PharmacyController(
      repository: const SeededPharmacyRepository(),
      orderRepository: const _ThrowingPharmacyOrderRepository(),
      activityController: throwingActivityController,
      now: () => DateTime.utc(2026, 7, 27, 12),
      storage: MemoryCartStorage<PharmacyCartItem>(),
    );
    await throwingController.loadProducts(
      storeId: SeededPharmacyRepository.defaultStoreId,
    );
    throwingController.addProduct(throwingController.products.first);

    const details = PharmacyCheckoutDetails(
      customerName: 'Asha Ali',
      phoneNumber: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      addressLine: 'Taleex Road, blue gate',
      deliveryInstructions: 'Please call on arrival.',
    );

    final result = await throwingController.placeDemoOrder(details);

    expect(result.isSuccess, isFalse);
    expect(
      result.validation.errorFor('order'),
      contains('The pharmacy order could not be saved'),
    );
    expect(throwingController.isLoading, isFalse);
    expect(throwingController.isCartEmpty, isFalse);
    expect(throwingController.cartItems, hasLength(1));
    expect(throwingActivityController.items, isEmpty);
  });

  group('catalog staleness and pull-to-refresh', () {
    test(
      'loadProducts does not refetch an already-loaded, fresh catalog',
      () async {
        final repository = _CountingPharmacyRepository();
        final now = DateTime.utc(2026, 8, 27, 12);
        final freshController = PharmacyController(
          repository: repository,
          activityController: ActivityController(),
          now: () => now,
          storage: MemoryCartStorage<PharmacyCartItem>(),
        );

        await freshController.loadProducts(
          storeId: SeededPharmacyRepository.defaultStoreId,
        );
        expect(repository.fetchCount, 1);

        await freshController.loadProducts(
          storeId: SeededPharmacyRepository.defaultStoreId,
        );
        expect(
          repository.fetchCount,
          1,
          reason: 'a fresh catalog should not be refetched',
        );
      },
    );

    test('loadProducts refetches once the catalog goes stale', () async {
      final repository = _CountingPharmacyRepository();
      var now = DateTime.utc(2026, 8, 27, 12);
      final staleController = PharmacyController(
        repository: repository,
        activityController: ActivityController(),
        now: () => now,
        storage: MemoryCartStorage<PharmacyCartItem>(),
      );

      await staleController.loadProducts(
        storeId: SeededPharmacyRepository.defaultStoreId,
      );
      expect(repository.fetchCount, 1);
      expect(staleController.isStale, isFalse);

      now = now.add(PharmacyController.catalogStaleAfter);
      expect(staleController.isStale, isTrue);

      await staleController.loadProducts(
        storeId: SeededPharmacyRepository.defaultStoreId,
      );
      expect(repository.fetchCount, 2);
      expect(staleController.isStale, isFalse);
    });

    test(
      'loadProducts(forceRefresh: true) always refetches regardless of staleness',
      () async {
        final repository = _CountingPharmacyRepository();
        final now = DateTime.utc(2026, 8, 27, 12);
        final forcedController = PharmacyController(
          repository: repository,
          activityController: ActivityController(),
          now: () => now,
          storage: MemoryCartStorage<PharmacyCartItem>(),
        );

        await forcedController.loadProducts(
          storeId: SeededPharmacyRepository.defaultStoreId,
        );
        expect(repository.fetchCount, 1);

        await forcedController.loadProducts(
          storeId: SeededPharmacyRepository.defaultStoreId,
          forceRefresh: true,
        );
        expect(repository.fetchCount, 2);
      },
    );
  });

  group('store-scoped catalog (issue #141)', () {
    test('loadProducts scopes the catalog to one pharmacy at a time', () async {
      final repository = _MultiStorePharmacyRepository();
      final multiStoreController = PharmacyController(
        repository: repository,
        activityController: ActivityController(),
        storage: MemoryCartStorage<PharmacyCartItem>(),
      );

      await multiStoreController.loadProducts(storeId: 'store-a');
      expect(multiStoreController.currentStoreId, 'store-a');
      expect(
        multiStoreController.products.map((product) => product.storeId),
        everyElement('store-a'),
      );

      // Switching to a different pharmacy always refetches — even though
      // the previous load is still fresh — and replaces the product list
      // rather than appending to it.
      await multiStoreController.loadProducts(storeId: 'store-b');
      expect(multiStoreController.currentStoreId, 'store-b');
      expect(
        multiStoreController.products.map((product) => product.storeId),
        everyElement('store-b'),
      );
      expect(repository.fetchCount, 2);
    });

    test('loadProducts narrows results with a search query', () async {
      final multiStoreController = PharmacyController(
        repository: _MultiStorePharmacyRepository(),
        activityController: ActivityController(),
        storage: MemoryCartStorage<PharmacyCartItem>(),
      );

      await multiStoreController.loadProducts(
        storeId: 'store-a',
        searchQuery: 'Vitamin',
      );

      expect(multiStoreController.products, hasLength(1));
      expect(multiStoreController.products.single.name, 'Vitamin A (Store A)');
    });

    test('adding a product from a different pharmacy is rejected without '
        'replaceStoreCart', () async {
      final storeA = PharmacyProduct(
        id: 'a-1',
        storeId: 'store-a',
        name: 'Store A item',
        description: '',
        category: 'General',
        unitPrice: 3,
        stockQuantity: 5,
        saleType: PharmacySaleType.overTheCounter,
      );
      final storeB = PharmacyProduct(
        id: 'b-1',
        storeId: 'store-b',
        name: 'Store B item',
        description: '',
        category: 'General',
        unitPrice: 4,
        stockQuantity: 5,
        saleType: PharmacySaleType.overTheCounter,
      );

      expect(controller.addProduct(storeA), PharmacyCartAddResult.added);
      expect(
        controller.addProduct(storeB),
        PharmacyCartAddResult.storeConflict,
      );
      expect(controller.cartItems, hasLength(1));
      expect(controller.cartItems.single.product.id, 'a-1');

      expect(
        controller.addProduct(storeB, replaceStoreCart: true),
        PharmacyCartAddResult.added,
      );
      expect(controller.cartItems, hasLength(1));
      expect(controller.cartItems.single.product.id, 'b-1');
    });
  });
}

/// A [PharmacyRepository] fake backing two distinct pharmacies, so
/// store-scoping (and per-store search) can be exercised without a live
/// Supabase client.
class _MultiStorePharmacyRepository implements PharmacyRepository {
  int fetchCount = 0;

  static const _products = <PharmacyProduct>[
    PharmacyProduct(
      id: 'store-a-vitamin',
      storeId: 'store-a',
      name: 'Vitamin A (Store A)',
      description: 'Store A vitamin.',
      category: 'Vitamins',
      unitPrice: 3,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'store-a-bandages',
      storeId: 'store-a',
      name: 'Bandages (Store A)',
      description: 'Store A first aid.',
      category: 'First aid',
      unitPrice: 2,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'store-b-cough-syrup',
      storeId: 'store-b',
      name: 'Cough Syrup (Store B)',
      description: 'Store B cold & flu.',
      category: 'Cold & flu',
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
    fetchCount++;
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

/// A [PharmacyOrderRepository] fake that always fails, simulating a network
/// error, Supabase exception, or RPC validation error surfaced during
/// order placement.
class _ThrowingPharmacyOrderRepository implements PharmacyOrderRepository {
  const _ThrowingPharmacyOrderRepository();

  @override
  Future<String> placeOrder(PharmacyOrderRequest request) {
    throw Exception('Simulated network failure while placing pharmacy order');
  }
}
