import 'dart:async';

import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/shared/models/delivery_details.dart';
import 'package:chowflow/services/shared/data/rpc_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/controllers.dart';
import 'helpers/memory_cart_storage.dart';

void main() {
  late GroceryController controller;
  late ActivityController activityController;
  late MemoryCartStorage<GroceryCartLine> storage;

  setUp(() async {
    activityController = ActivityController();
    storage = MemoryCartStorage<GroceryCartLine>();
    controller = buildGroceryController(
      activityController: activityController,
      storage: storage,
    );
    await controller.load();
  });

  GroceryProduct product(String id) {
    return controller.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == id);
  }

  test('calculates unit and weighted product totals in USD amounts', () {
    final rice = product('bakaal-rice');
    final bananas = product('bakaal-bananas');

    expect(controller.addProduct(rice), GroceryAddResult.added);
    expect(controller.addProduct(bananas), GroceryAddResult.added);
    expect(controller.setQuantity(bananas.id, 1.5), isTrue);

    expect(controller.subtotal, 1120);
    expect(controller.deliveryFee, 250);
    expect(controller.total, 1370);
  });

  test('does not add unavailable products or exceed available stock', () {
    final tomatoes = product('bakaal-tomatoes');
    final milk = product('bakaal-milk');

    expect(controller.addProduct(tomatoes), GroceryAddResult.unavailable);
    expect(controller.isEmpty, isTrue);

    expect(controller.addProduct(milk), GroceryAddResult.added);
    expect(controller.setQuantity(milk.id, 3), isTrue);
    expect(controller.increment(milk.id), isFalse);
    expect(controller.cart.single.quantity, 3);
  });

  test('adds several quantity steps at once, all or nothing', () {
    final bananas = product('bakaal-bananas'); // 12 kg, 0.5 kg steps

    expect(controller.addProduct(bananas, steps: 4), GroceryAddResult.added);
    expect(controller.cart.single.quantity, 2);

    expect(
      controller.addProduct(bananas, steps: 21),
      GroceryAddResult.stockLimitReached,
    );
    expect(controller.cart.single.quantity, 2);
  });

  test('a product photo URL survives the local cart snapshot', () {
    final withPhoto = GroceryProduct.fromJson({
      ...product('bakaal-bananas').toJson(),
      'image_url': 'https://cdn.test/bananas.jpg',
    });
    expect(
      GroceryProduct.fromJson(withPhoto.toJson()).imageUrl,
      'https://cdn.test/bananas.jpg',
    );
    expect(product('bakaal-bananas').imageUrl, isNull);
  });

  test('requires and records the selected substitution preference', () async {
    controller.addProduct(product('bakaal-rice'));
    const delivery = DeliveryDetails(note: 'Near Taleex Road');

    final missingPreference = await controller.confirmOrder(
      delivery: delivery,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: null,
    );
    expect(missingPreference.isSuccess, isFalse);
    expect(
      missingPreference.errors,
      contains('Choose a substitution preference.'),
    );

    final result = await controller.confirmOrder(
      delivery: delivery,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: GrocerySubstitutionPreference.contactMe,
      now: DateTime.utc(2026, 7, 27, 12),
    );

    expect(result.isSuccess, isTrue);
    expect(
      result.confirmation!.substitutionPreference,
      GrocerySubstitutionPreference.contactMe,
    );
    expect(activityController.items, hasLength(1));
    expect(activityController.items.single.serviceId, ServiceId.grocery);
    expect(activityController.items.single.status, 'Confirmed');
    expect(controller.isEmpty, isTrue);
  });

  test('checkout validates cart, slot, and preference — no address', () {
    final errors = controller.validateCheckout(
      slot: null,
      substitutionPreference: null,
    );

    expect(errors, contains('Add at least one grocery item.'));
    expect(errors, hasLength(3));
    expect(errors, contains('Choose a delivery slot.'));
    expect(errors, contains('Choose a substitution preference.'));
  });

  test('grocery cart survives a simulated app reload', () async {
    await controller.loadForOwner('user-1');
    final rice = product('bakaal-rice');
    controller.addProduct(rice);
    controller.setQuantity(rice.id, 2);
    await controller.pendingCartWrite;

    // Simulate the app restarting: a brand new controller backed by the
    // same underlying storage should restore the persisted cart.
    final restarted = buildGroceryController(
      activityController: activityController,
      storage: storage,
    );
    await restarted.load();
    await restarted.loadForOwner('user-1');

    expect(restarted.cart, hasLength(1));
    expect(restarted.cart.single.product.id, rice.id);
    expect(restarted.cart.single.quantity, 2);
  });

  test('switching accounts clears and reloads the grocery cart', () async {
    await controller.loadForOwner('user-1');
    controller.addProduct(product('bakaal-rice'));
    expect(controller.isNotEmpty, isTrue);
    await controller.pendingCartWrite;

    await controller.loadForOwner('user-2');
    expect(controller.isEmpty, isTrue);

    controller.addProduct(product('bakaal-bananas'));
    await controller.pendingCartWrite;
    await controller.loadForOwner('user-1');
    expect(controller.cart.single.product.id, 'bakaal-rice');

    await controller.loadForOwner('user-2');
    expect(controller.cart.single.product.id, 'bakaal-bananas');
  });

  test('confirmOrder surfaces an error, resets loading, and keeps the cart '
      'when the order repository throws', () async {
    final throwingController = buildGroceryController(
      orderRepository: const _ThrowingGroceryOrderRepository(),
      activityController: activityController,
    );
    await throwingController.load();
    final rice = throwingController.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == 'bakaal-rice');
    throwingController.addProduct(rice);

    const delivery = DeliveryDetails(note: 'Near Taleex Road');

    final result = await throwingController.confirmOrder(
      delivery: delivery,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: GrocerySubstitutionPreference.contactMe,
      now: DateTime.utc(2026, 7, 27, 12),
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.errors,
      contains('The grocery order could not be saved. Please try again.'),
    );
    expect(throwingController.isLoading, isFalse);
    expect(throwingController.isEmpty, isFalse);
    expect(throwingController.cart, hasLength(1));
    expect(throwingController.lastConfirmation, isNull);
    expect(activityController.items, isEmpty);
  });

  test('confirmOrder surfaces a generic error, resets loading, and keeps '
      'the cart when place_grocery_order rejects an elapsed delivery slot '
      '(issue #82)', () async {
    // `place_grocery_order` raises a plain Postgres exception -- surfaced to
    // supabase_flutter as a `PostgrestException` -- when the selected slot's
    // computed delivery window has already elapsed. There is no per-message
    // mapping for `place_grocery_order` failures in the grocery checkout
    // flow (unlike e.g. `describeAuthError` for auth): every raised
    // exception from this RPC, including this new one, already funnels
    // through `confirmDemoOrder`'s generic `catch` into the same
    // "could not be saved" message, so a real Postgres error message is
    // never shown to the user and the flow does not crash.
    final elapsedSlotController = buildGroceryController(
      orderRepository: const _ElapsedSlotGroceryOrderRepository(),
      activityController: activityController,
    );
    await elapsedSlotController.load();
    final rice = elapsedSlotController.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == 'bakaal-rice');
    elapsedSlotController.addProduct(rice);

    const delivery = DeliveryDetails(note: 'Near Taleex Road');

    final result = await elapsedSlotController.confirmOrder(
      delivery: delivery,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: GrocerySubstitutionPreference.contactMe,
      now: DateTime.utc(2026, 7, 27, 20),
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.errors,
      contains('The grocery order could not be saved. Please try again.'),
    );
    expect(
      result.errors.join(),
      isNot(contains('delivery window has already passed')),
    );
    expect(elapsedSlotController.isLoading, isFalse);
    expect(elapsedSlotController.isEmpty, isFalse);
    expect(elapsedSlotController.cart, hasLength(1));
    expect(elapsedSlotController.lastConfirmation, isNull);
    expect(activityController.items, isEmpty);
  });

  test('confirmOrder ignores a second call while a submission is in flight '
      '(issue #59)', () async {
    final repository = _ControllableGroceryOrderRepository();
    final submittingController = buildGroceryController(
      orderRepository: repository,
      activityController: activityController,
    );
    await submittingController.load();
    final rice = submittingController.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == 'bakaal-rice');
    submittingController.addProduct(rice);

    const delivery = DeliveryDetails(note: 'Near Taleex Road');

    final first = submittingController.confirmOrder(
      delivery: delivery,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: GrocerySubstitutionPreference.contactMe,
    );
    expect(submittingController.isSubmitting, isTrue);

    // A second call while the first is still in flight must be a no-op:
    // it must not reach the repository and must not disturb the cart or
    // submission state the first call owns.
    final second = await submittingController.confirmOrder(
      delivery: delivery,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: GrocerySubstitutionPreference.contactMe,
    );
    expect(second.isSuccess, isFalse);
    expect(repository.callCount, 1);

    repository.complete('grocery-order-1');
    final result = await first;

    expect(result.isSuccess, isTrue);
    expect(repository.callCount, 1);
    expect(submittingController.isSubmitting, isFalse);
  });

  test(
    'confirmOrder forwards a caller-supplied idempotency key to the '
    'repository, and synthesizes one when none is given (issue #59)',
    () async {
      final repository = _RecordingGroceryOrderRepository();
      final recordingController = buildGroceryController(
        orderRepository: repository,
        activityController: activityController,
      );
      await recordingController.load();
      final rice = recordingController.stores
          .expand((store) => store.products)
          .firstWhere((product) => product.id == 'bakaal-rice');

      const delivery = DeliveryDetails(note: 'Near Taleex Road');

      recordingController.addProduct(rice);
      await recordingController.confirmOrder(
        delivery: delivery,
        slot: GroceryController.deliverySlots.first,
        substitutionPreference: GrocerySubstitutionPreference.contactMe,
        idempotencyKey: 'attempt-key-1',
      );

      expect(repository.lastRequest!.idempotencyKey, 'attempt-key-1');

      // A second, independent attempt (cart repopulated after the first
      // order cleared it) with no key supplied still gets a non-empty key
      // generated for it, so the RPC always has one to key its own
      // de-duplication on.
      recordingController.addProduct(rice);
      await recordingController.confirmOrder(
        delivery: delivery,
        slot: GroceryController.deliverySlots.first,
        substitutionPreference: GrocerySubstitutionPreference.contactMe,
      );

      expect(repository.lastRequest!.idempotencyKey, isNotNull);
      expect(repository.lastRequest!.idempotencyKey, isNotEmpty);
    },
  );

  test('confirmOrder records the RPC-returned total, not the client cart '
      'total, into the activity feed and confirmation (issue #60)', () async {
    // A price returned by the RPC that deliberately differs from the
    // client-computed cart total, simulating a product price that
    // changed between the cart being built and this checkout being
    // confirmed -- the RPC's number must win for both the activity feed
    // and the returned confirmation.
    final repository = _RecordingGroceryOrderRepository(
      placed: const PlacedOrder(
        orderId: 'grocery-server-order',
        subtotal: 5000,
        deliveryFee: 250,
        tax: 0,
        total: 5250,
      ),
    );
    final serverPricedController = buildGroceryController(
      orderRepository: repository,
      activityController: activityController,
    );
    await serverPricedController.load();
    final rice = serverPricedController.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == 'bakaal-rice');
    serverPricedController.addProduct(rice);
    final clientComputedTotal = serverPricedController.total;
    expect(clientComputedTotal, isNot(5250));

    const delivery = DeliveryDetails(note: 'Near Taleex Road');

    final result = await serverPricedController.confirmOrder(
      delivery: delivery,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: GrocerySubstitutionPreference.contactMe,
    );

    expect(result.isSuccess, isTrue);
    expect(result.confirmation!.amount, 5250);
    expect(activityController.items.single.amount, 5250);
  });

  group('catalog staleness and pull-to-refresh', () {
    test('load does not refetch an already-loaded, fresh catalog', () async {
      final repository = _CountingGroceryRepository();
      final now = DateTime.utc(2026, 8, 27, 12);
      final freshController = buildGroceryController(
        repository: repository,
        now: () => now,
      );

      await freshController.load();
      expect(repository.fetchCount, 1);

      await freshController.load();
      expect(
        repository.fetchCount,
        1,
        reason: 'a fresh catalog should not be refetched',
      );
    });

    test('load refetches once the catalog goes stale', () async {
      final repository = _CountingGroceryRepository();
      var now = DateTime.utc(2026, 8, 27, 12);
      final staleController = buildGroceryController(
        repository: repository,
        now: () => now,
      );

      await staleController.load();
      expect(repository.fetchCount, 1);
      expect(staleController.isStale, isFalse);

      now = now.add(GroceryController.catalogStaleAfter);
      expect(staleController.isStale, isTrue);

      await staleController.load();
      expect(repository.fetchCount, 2);
      expect(staleController.isStale, isFalse);
    });

    test(
      'load(forceRefresh: true) always refetches regardless of staleness',
      () async {
        final repository = _CountingGroceryRepository();
        final now = DateTime.utc(2026, 8, 27, 12);
        final forcedController = buildGroceryController(
          repository: repository,
          now: () => now,
        );

        await forcedController.load();
        expect(repository.fetchCount, 1);

        await forcedController.load(forceRefresh: true);
        expect(repository.fetchCount, 2);
      },
    );
  });
}

class _CountingGroceryRepository implements GroceryRepository {
  int fetchCount = 0;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    fetchCount++;
    return const SeededGroceryRepository().fetchStores();
  }
}

/// A [GroceryOrderRepository] fake that always fails, simulating a network
/// error, Supabase exception, or RPC validation error surfaced during
/// order placement.
class _ThrowingGroceryOrderRepository implements GroceryOrderRepository {
  const _ThrowingGroceryOrderRepository();

  @override
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request) {
    throw Exception('Simulated network failure while placing grocery order');
  }
}

/// A [GroceryOrderRepository] fake that throws the same
/// [PostgrestException] shape `place_grocery_order` raises (issue #82) when
/// the selected delivery slot's computed window has already elapsed.
class _ElapsedSlotGroceryOrderRepository implements GroceryOrderRepository {
  const _ElapsedSlotGroceryOrderRepository();

  @override
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request) {
    throw const PostgrestException(
      message:
          'The selected delivery window has already passed. Please choose '
          'another delivery slot.',
      code: 'P0001',
    );
  }
}

/// A [GroceryOrderRepository] fake that records every request it receives
/// and resolves immediately with an incrementing order id, or with a
/// caller-supplied [placed] result (used to simulate the RPC pricing an
/// order differently than the client's cart estimate).
class _RecordingGroceryOrderRepository implements GroceryOrderRepository {
  _RecordingGroceryOrderRepository({this.placed});

  final PlacedOrder? placed;
  int callCount = 0;
  GroceryOrderRequest? lastRequest;

  @override
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request) async {
    callCount++;
    lastRequest = request;
    return placed ??
        PlacedOrder(
          orderId: 'grocery-order-$callCount',
          subtotal: 1000,
          deliveryFee: 250,
          tax: 0,
          total: 1250,
        );
  }
}

/// A [GroceryOrderRepository] fake whose [placeOrder] only resolves once the
/// test calls [complete], so a test can observe controller state (e.g.
/// [GroceryController.isSubmitting]) while a submission is still in flight.
class _ControllableGroceryOrderRepository implements GroceryOrderRepository {
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
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request) {
    callCount++;
    return _pending.future;
  }
}
