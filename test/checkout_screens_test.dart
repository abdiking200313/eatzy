import 'dart:async';

import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/food/data/food_repository.dart';
import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/models/food_models.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/services/food/presentation/checkout_screen.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_checkout_screen.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_checkout.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import 'package:chowflow/services/shared/data/rpc_helpers.dart';
import 'package:chowflow/services/shared/presentation/confirm_order_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/controllers.dart';
import 'helpers/memory_cart_storage.dart';

/// Checkout screens for every vertical, plus the shared `confirmDemoOrder`
/// flow they all delegate to. The double-tap guard (issue #59) is
/// table-driven across food, grocery and pharmacy.
void main() {
  const burger = CartItem(
    menuItemId: 'burger-1',
    restaurantId: 'restaurant-1',
    restaurantName: 'Test Kitchen',
    name: 'Classic Burger',
    unitPrice: 10,
    imageUrl: '',
  );

  Future<CartController> foodCart() async {
    final cartController = CartController(storage: MemoryCartStorage());
    await cartController.loadForOwner('user-1');
    await cartController.addItem(burger);
    return cartController;
  }

  final placeOrderButton = find.byKey(const Key('checkout-place-order'));

  group('food checkout', () {
    testWidgets(
      'placing an order surfaces an error, resets the submit button, and '
      'keeps the cart when the order repository throws',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final cartController = await foodCart();
        final activityController = ActivityController();

        await tester.pumpWidget(
          MaterialApp(
            home: CheckoutScreen(
              cartController: cartController,
              orderRepository: const _ThrowingFoodOrderRepository(),
              activityController: activityController,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(placeOrderButton);
        // Let the submission start (isSubmitting = true) and complete.
        await tester.pump();
        await tester.pump();

        expect(
          find.text('The food order could not be saved. Please try again.'),
          findsOneWidget,
        );
        // The submit button resets back to its idle label instead of being
        // stuck on "Placing order...".
        expect(find.textContaining('Place order'), findsOneWidget);
        expect(find.text('Placing order...'), findsNothing);

        // The cart must not be cleared on a failed order placement.
        expect(cartController.items, hasLength(1));
        expect(cartController.items.single.menuItemId, burger.menuItemId);

        // No activity should have been recorded for the failed order.
        expect(activityController.items, isEmpty);
      },
    );

    testWidgets(
      'asks only for an optional delivery note (no address, no payment '
      'picker) and sends the note with the order',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repository = _RecordingFoodOrderRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: CheckoutScreen(
              cartController: await foodCart(),
              orderRepository: repository,
              activityController: ActivityController(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(
          find.text('Delivery note / landmark (optional)'),
          findsOneWidget,
        );
        expect(find.textContaining('Street'), findsNothing);
        expect(find.textContaining('District'), findsNothing);
        expect(find.text('Payment method'), findsNothing);
        expect(find.text('Pay on delivery'), findsOneWidget);
        expect(find.text('Classic Burger ×1'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('checkout-delivery-note')),
          'Blue gate',
        );
        await tester.tap(placeOrderButton);
        await tester.pump();

        expect(repository.requests.single.delivery.note, 'Blue gate');
      },
    );
  });

  group('grocery checkout', () {
    testWidgets(
      'an incomplete grocery checkout flags only the slot and substitution '
      'sections, since there are no address fields to fill',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = await buildLoadedGroceryController();
        controller.addProduct(
          controller.stores
              .expand((store) => store.products)
              .firstWhere((product) => product.isAvailable),
        );

        await tester.pumpWidget(
          MaterialApp(home: GroceryCheckoutScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);

        await tester.tap(placeOrderButton);
        await tester.pumpAndSettle();

        expect(find.text('Choose a delivery slot.'), findsOneWidget);
        expect(find.text('Choose a substitution preference.'), findsOneWidget);
        expect(find.byKey(const Key('checkout-error')), findsNothing);
      },
    );
  });

  group('a double-tap on the submit button places only one order (#59)', () {
    final cases = <_DoubleTapCase>[
      _DoubleTapCase(
        service: 'food',
        build: (pending) async => CheckoutScreen(
          cartController: await foodCart(),
          orderRepository: _PendingFoodOrderRepository(pending),
          activityController: ActivityController(),
        ),
        fillForm: (tester) async {},
      ),
      _DoubleTapCase(
        service: 'grocery',
        build: (pending) async {
          final controller = await buildLoadedGroceryController(
            orderRepository: _PendingGroceryOrderRepository(pending),
          );
          controller.addProduct(
            controller.stores
                .expand((store) => store.products)
                .firstWhere((product) => product.isAvailable),
          );
          return GroceryCheckoutScreen(controller: controller);
        },
        fillForm: (tester) async {
          await tester.tap(
            find.byType(RadioListTile<GroceryDeliverySlot>).first,
          );
          await tester.tap(
            find.byType(RadioListTile<GrocerySubstitutionPreference>).first,
          );
        },
      ),
      _DoubleTapCase(
        service: 'pharmacy',
        build: (pending) async {
          final controller = await buildLoadedPharmacyController(
            orderRepository: _PendingPharmacyOrderRepository(pending),
          );
          controller.addProduct(controller.products.first);
          return PharmacyCheckoutScreen(controller: controller);
        },
        fillForm: (tester) async {},
      ),
    ];

    for (final c in cases) {
      testWidgets(c.service, (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final pending = _PendingOrders();
        await tester.pumpWidget(MaterialApp(home: await c.build(pending)));
        await tester.pumpAndSettle();

        await c.fillForm(tester);
        await tester.pumpAndSettle();

        // Tap twice in a row before the first submission's RPC has resolved.
        await tester.tap(placeOrderButton);
        await tester.pump();
        expect(find.text('Placing order...'), findsOneWidget);

        await tester.tap(placeOrderButton);
        await tester.pump();

        // Only one request ever reached the repository: the button was
        // disabled for the second tap, and the controller's own
        // `isSubmitting` guard is a second line of defense either way. The
        // first submission is left in flight (never completed) so this test
        // does not also have to stand up routes for the post-success
        // navigation, which is outside what this test is about.
        expect(pending.callCount, 1);
      });
    }
  });

  group('confirmDemoOrder', () {
    test('passes the thrown error and stack trace to onSaveFailed', () async {
      final thrown = Exception('boom');
      Object? capturedError;
      StackTrace? capturedStackTrace;

      final result = await confirmDemoOrder<String, bool, String>(
        validation: true,
        isValid: (validation) => validation,
        onInvalid: (_) => 'invalid',
        placeOrder: () async => throw thrown,
        fallbackOrder: () => 'fallback-order',
        onSaveFailed: (error, stackTrace) {
          capturedError = error;
          capturedStackTrace = stackTrace;
          return 'save-failed';
        },
        recordActivity: (_) {},
        clearCart: () {},
        onConfirmed: (_) => 'confirmed',
      );

      expect(result, 'save-failed');
      expect(capturedError, same(thrown));
      expect(capturedStackTrace, isNotNull);
    });

    test('returns onConfirmed and records activity/clears the cart when '
        'placeOrder succeeds', () async {
      var activityRecorded = false;
      var cartCleared = false;

      final result = await confirmDemoOrder<String, bool, String>(
        validation: true,
        isValid: (validation) => validation,
        onInvalid: (_) => 'invalid',
        placeOrder: () async => 'order-1',
        fallbackOrder: () => 'fallback-order',
        onSaveFailed: (error, stackTrace) => 'save-failed',
        recordActivity: (order) {
          expect(order, 'order-1');
          activityRecorded = true;
        },
        clearCart: () => cartCleared = true,
        onConfirmed: (order) => 'confirmed:$order',
      );

      expect(result, 'confirmed:order-1');
      expect(activityRecorded, isTrue);
      expect(cartCleared, isTrue);
    });

    test('returns onInvalid without placing an order', () async {
      var placeOrderCalled = false;

      final result = await confirmDemoOrder<String, bool, String>(
        validation: false,
        isValid: (validation) => validation,
        onInvalid: (_) => 'invalid',
        placeOrder: () async {
          placeOrderCalled = true;
          return 'order-1';
        },
        fallbackOrder: () => 'fallback-order',
        onSaveFailed: (error, stackTrace) => 'save-failed',
        recordActivity: (_) {},
        clearCart: () {},
        onConfirmed: (_) => 'confirmed',
      );

      expect(result, 'invalid');
      expect(placeOrderCalled, isFalse);
    });
  });
}

class _DoubleTapCase {
  const _DoubleTapCase({
    required this.service,
    required this.build,
    required this.fillForm,
  });

  final String service;
  final Future<Widget> Function(_PendingOrders pending) build;
  final Future<void> Function(WidgetTester tester) fillForm;
}

/// Counts `placeOrder` calls and never resolves them, so a widget test can
/// exercise a second tap while the first submission is still in flight.
class _PendingOrders {
  int callCount = 0;

  Future<PlacedOrder> place() {
    callCount++;
    return Completer<PlacedOrder>().future;
  }
}

class _PendingFoodOrderRepository implements FoodOrderRepository {
  _PendingFoodOrderRepository(this.pending);

  final _PendingOrders pending;

  @override
  Future<PlacedOrder> placeOrder(FoodOrderRequest request) => pending.place();
}

class _PendingGroceryOrderRepository implements GroceryOrderRepository {
  _PendingGroceryOrderRepository(this.pending);

  final _PendingOrders pending;

  @override
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request) =>
      pending.place();
}

class _PendingPharmacyOrderRepository implements PharmacyOrderRepository {
  _PendingPharmacyOrderRepository(this.pending);

  final _PendingOrders pending;

  @override
  Future<PlacedOrder> placeOrder(PharmacyOrderRequest request) =>
      pending.place();
}

/// Always fails, simulating a network error, Supabase exception, or RPC
/// validation error surfaced when placing a food order.
class _ThrowingFoodOrderRepository implements FoodOrderRepository {
  const _ThrowingFoodOrderRepository();

  @override
  Future<PlacedOrder> placeOrder(FoodOrderRequest request) {
    throw Exception('Simulated network failure while placing food order');
  }
}

/// Records every request and leaves it in flight, for asserting what was sent.
class _RecordingFoodOrderRepository implements FoodOrderRepository {
  final requests = <FoodOrderRequest>[];

  @override
  Future<PlacedOrder> placeOrder(FoodOrderRequest request) {
    requests.add(request);
    return Completer<PlacedOrder>().future;
  }
}
