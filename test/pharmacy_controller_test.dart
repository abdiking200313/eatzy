import 'dart:async';

import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_checkout.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:chowflow/services/shared/data/rpc_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/controllers.dart';
import 'helpers/memory_cart_storage.dart';

void main() {
  late ActivityController activityController;
  late PharmacyController controller;
  late MemoryCartStorage<PharmacyCartItem> storage;

  setUp(() async {
    activityController = ActivityController();
    storage = MemoryCartStorage<PharmacyCartItem>();
    controller = buildPharmacyController(
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
    expect(controller.subtotal, 550);
    expect(controller.total, 800);

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
      recipientName: '',
      phone: '12',
      city: '',
      district: '',
      street: '',
    );

    final validation = controller.validateCheckout(emptyDetails);

    expect(validation.isValid, isFalse);
    expect(validation.errorFor('cart'), isNotNull);
    expect(validation.errorFor('recipientName'), isNotNull);
    expect(validation.errorFor('phone'), isNotNull);
    expect(validation.errorFor('city'), contains('Somalia'));
    expect(validation.errorFor('district'), isNotNull);
    expect(validation.errorFor('street'), isNotNull);
    expect(PharmacyCheckoutDetails.country, 'Somalia');
  });

  test('demo checkout records pharmacy activity and clears its cart', () async {
    controller.addProduct(controller.products.first);
    const details = PharmacyCheckoutDetails(
      recipientName: 'Asha Ali',
      phone: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      street: 'Taleex Road, blue gate',
      deliveryInstructions: 'Please call on arrival.',
    );

    final result = await controller.placeDemoOrder(details);

    expect(result.isSuccess, isTrue);
    expect(result.message, contains('No payment was processed'));
    expect(controller.isCartEmpty, isTrue);
    expect(activityController.items, hasLength(1));
    expect(activityController.items.single.serviceId, ServiceId.pharmacy);
    expect(activityController.items.single.status, 'Demo confirmed');
    expect(activityController.items.single.amount, 525);
  });

  test('pharmacy cart survives a simulated app reload', () async {
    await controller.loadForOwner('user-1');
    final paracetamol = controller.products.first;
    controller.addProduct(paracetamol);
    controller.increment(paracetamol.id);
    await controller.pendingCartWrite;

    // Simulate the app restarting: a brand new controller backed by the
    // same underlying storage should restore the persisted cart.
    final restarted = buildPharmacyController(
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
    final throwingController = buildPharmacyController(
      orderRepository: const _ThrowingPharmacyOrderRepository(),
      activityController: throwingActivityController,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await throwingController.loadProducts(
      storeId: SeededPharmacyRepository.defaultStoreId,
    );
    throwingController.addProduct(throwingController.products.first);

    const details = PharmacyCheckoutDetails(
      recipientName: 'Asha Ali',
      phone: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      street: 'Taleex Road, blue gate',
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

  test('placeDemoOrder ignores a second call while a submission is in flight '
      '(issue #59)', () async {
    final repository = _ControllablePharmacyOrderRepository();
    final submittingController = buildPharmacyController(
      orderRepository: repository,
      activityController: activityController,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await submittingController.loadProducts(
      storeId: SeededPharmacyRepository.defaultStoreId,
    );
    submittingController.addProduct(submittingController.products.first);

    const details = PharmacyCheckoutDetails(
      recipientName: 'Asha Ali',
      phone: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      street: 'Taleex Road, blue gate',
    );

    final first = submittingController.placeDemoOrder(details);
    expect(submittingController.isSubmitting, isTrue);

    // A second call while the first is still in flight must be a no-op:
    // it must not reach the repository and must not disturb the cart or
    // submission state the first call owns.
    final second = await submittingController.placeDemoOrder(details);
    expect(second.isSuccess, isFalse);
    expect(repository.callCount, 1);

    repository.complete('pharmacy-order-1');
    final result = await first;

    expect(result.isSuccess, isTrue);
    expect(repository.callCount, 1);
    expect(submittingController.isSubmitting, isFalse);
  });

  test(
    'placeDemoOrder forwards a caller-supplied idempotency key to the '
    'repository, and synthesizes one when none is given (issue #59)',
    () async {
      final repository = _RecordingPharmacyOrderRepository();
      final recordingController = buildPharmacyController(
        orderRepository: repository,
        activityController: activityController,
        now: () => DateTime.utc(2026, 7, 27, 12),
      );
      await recordingController.loadProducts(
        storeId: SeededPharmacyRepository.defaultStoreId,
      );

      const details = PharmacyCheckoutDetails(
        recipientName: 'Asha Ali',
        phone: '+252 61 234 5678',
        city: 'Mogadishu',
        district: 'Hodan',
        street: 'Taleex Road, blue gate',
      );

      recordingController.addProduct(recordingController.products.first);
      await recordingController.placeDemoOrder(
        details,
        idempotencyKey: 'attempt-key-1',
      );

      expect(repository.lastRequest!.idempotencyKey, 'attempt-key-1');

      // A second, independent attempt (cart repopulated after the first
      // order cleared it) with no key supplied still gets a non-empty key
      // generated for it, so the RPC always has one to key its own
      // de-duplication on.
      recordingController.addProduct(recordingController.products.first);
      await recordingController.placeDemoOrder(details);

      expect(repository.lastRequest!.idempotencyKey, isNotNull);
      expect(repository.lastRequest!.idempotencyKey, isNotEmpty);
    },
  );

  test('placeDemoOrder records the RPC-returned total, not the client cart '
      'total, into the activity feed (issue #60)', () async {
    // A price returned by the RPC that deliberately differs from the
    // client-computed cart total, simulating a product price that
    // changed between the cart being built and this checkout being
    // confirmed -- the RPC's number must win.
    final repository = _RecordingPharmacyOrderRepository(
      placed: const PlacedOrder(
        orderId: 'pharmacy-server-order',
        subtotal: 4000,
        deliveryFee: 250,
        tax: 0,
        total: 4250,
      ),
    );
    final serverPricedController = buildPharmacyController(
      orderRepository: repository,
      activityController: activityController,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await serverPricedController.loadProducts(
      storeId: SeededPharmacyRepository.defaultStoreId,
    );
    serverPricedController.addProduct(serverPricedController.products.first);
    expect(serverPricedController.total, isNot(4250));

    const details = PharmacyCheckoutDetails(
      recipientName: 'Asha Ali',
      phone: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      street: 'Taleex Road, blue gate',
    );

    final result = await serverPricedController.placeDemoOrder(details);

    expect(result.isSuccess, isTrue);
    expect(activityController.items.single.amount, 4250);
  });

  group('catalog staleness and pull-to-refresh', () {
    test(
      'loadProducts does not refetch an already-loaded, fresh catalog',
      () async {
        final repository = _CountingPharmacyRepository();
        final now = DateTime.utc(2026, 8, 27, 12);
        final freshController = buildPharmacyController(
          repository: repository,
          now: () => now,
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
      final staleController = buildPharmacyController(
        repository: repository,
        now: () => now,
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
        final forcedController = buildPharmacyController(
          repository: repository,
          now: () => now,
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
      final multiStoreController = buildPharmacyController(
        repository: repository,
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
      final multiStoreController = buildPharmacyController(
        repository: _MultiStorePharmacyRepository(),
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
  Future<PlacedOrder> placeOrder(PharmacyOrderRequest request) {
    throw Exception('Simulated network failure while placing pharmacy order');
  }
}

/// A [PharmacyOrderRepository] fake that records every request it receives
/// and resolves immediately with an incrementing order id, or with a
/// caller-supplied [placed] result (used to simulate the RPC pricing an
/// order differently than the client's cart estimate).
class _RecordingPharmacyOrderRepository implements PharmacyOrderRepository {
  _RecordingPharmacyOrderRepository({this.placed});

  final PlacedOrder? placed;
  int callCount = 0;
  PharmacyOrderRequest? lastRequest;

  @override
  Future<PlacedOrder> placeOrder(PharmacyOrderRequest request) async {
    callCount++;
    lastRequest = request;
    return placed ??
        PlacedOrder(
          orderId: 'pharmacy-order-$callCount',
          subtotal: 1000,
          deliveryFee: 250,
          tax: 0,
          total: 1250,
        );
  }
}

/// A [PharmacyOrderRepository] fake whose [placeOrder] only resolves once
/// the test calls [complete], so a test can observe controller state (e.g.
/// [PharmacyController.isSubmitting]) while a submission is still in
/// flight.
class _ControllablePharmacyOrderRepository implements PharmacyOrderRepository {
  int callCount = 0;
  final _pending = Completer<PlacedOrder>();

  void complete(String orderId) => _pending.complete(
    PlacedOrder(
      orderId: orderId,
      subtotal: 1000,
      deliveryFee: 250,
      tax: 0,
      total: 1250,
    ),
  );

  @override
  Future<PlacedOrder> placeOrder(PharmacyOrderRequest request) {
    callCount++;
    return _pending.future;
  }
}
