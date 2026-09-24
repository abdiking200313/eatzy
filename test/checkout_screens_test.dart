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

  Future<void> fillFoodAddress(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('food-recipient-name')),
      'Amina Yusuf',
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-phone')),
      '+252 61 234 5678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-street')),
      'Maka Al-Mukarama Road',
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-district')),
      'Hodan',
    );
  }

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

        await fillFoodAddress(tester);
        await tester.tap(find.text('Place order'));
        // Let the submission start (isSubmitting = true) and complete.
        await tester.pump();
        await tester.pump();

        expect(
          find.text('The food order could not be saved. Please try again.'),
          findsOneWidget,
        );
        // The submit button resets back to its idle label instead of being
        // stuck on "Saving order...".
        expect(find.text('Place order'), findsOneWidget);
        expect(find.text('Saving order...'), findsNothing);

        // The cart must not be cleared on a failed order placement.
        expect(cartController.items, hasLength(1));
        expect(cartController.items.single.menuItemId, burger.menuItemId);

        // No activity should have been recorded for the failed order.
        expect(activityController.items, isEmpty);
      },
    );

    testWidgets(
      'submitting an incomplete food checkout shows errors inline below each '
      'invalid field, not just a generic list',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: CheckoutScreen(
              cartController: await foodCart(),
              orderRepository: const _ThrowingFoodOrderRepository(),
              activityController: ActivityController(),
            ),
          ),
        );
        await tester.pump();

        // Leave every address field blank and submit.
        await tester.tap(find.text('Place order'));
        await tester.pump();

        String? errorFor(String key) => tester
            .widget<TextField>(find.byKey(ValueKey(key)))
            .decoration
            ?.errorText;

        expect(errorFor('food-recipient-name'), 'Enter the recipient name.');
        expect(errorFor('food-phone'), 'Enter a valid phone number.');
        expect(errorFor('food-street'), 'Enter a street or landmark.');
        expect(errorFor('food-district'), 'Enter a district.');

        // The old generic bullet-list rendering is gone.
        expect(find.textContaining('• Enter'), findsNothing);

        // Submission never reached the (failing) repository, since the form
        // is still invalid — the order-save failure banner never appears.
        expect(
          find.text('The food order could not be saved. Please try again.'),
          findsNothing,
        );
      },
    );
  });

  group('grocery checkout', () {
    testWidgets(
      'submitting an incomplete grocery checkout shows errors inline below '
      'each invalid field, not just a generic banner',
      (tester) async {
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

        await tester.tap(find.textContaining('Confirm demo order'));
        await tester.pumpAndSettle();

        // Each invalid field carries its own inline error below it,
        // mirroring pharmacy checkout's errorText pattern, instead of one
        // generic list.
        expect(find.text('Enter the recipient name.'), findsOneWidget);
        expect(find.text('Enter a valid phone number.'), findsOneWidget);
        expect(find.text('Enter a street or landmark.'), findsOneWidget);
        expect(find.text('Enter a district.'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;
        for (final error in [
          'Choose a delivery slot.',
          'Choose a substitution preference.',
        ]) {
          await tester.scrollUntilVisible(
            find.text(error),
            300,
            scrollable: scrollable,
          );
          expect(find.text(error), findsOneWidget);
        }

        // The old generic "Please complete the following:" banner is gone.
        expect(find.text('Please complete the following:'), findsNothing);
      },
    );
  });

  group('a double-tap on the submit button places only one order (#59)', () {
    final cases = <_DoubleTapCase>[
      _DoubleTapCase(
        service: 'food',
        submitButton: find.text('Place order'),
        build: (pending) async => CheckoutScreen(
          cartController: await foodCart(),
          orderRepository: _PendingFoodOrderRepository(pending),
          activityController: ActivityController(),
        ),
        fillForm: fillFoodAddress,
      ),
      _DoubleTapCase(
        service: 'grocery',
        submitButton: find.textContaining('Confirm demo order'),
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
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(0), 'Amina');
          await tester.enterText(fields.at(1), '+252 61 234 5678');
          await tester.enterText(fields.at(2), 'Near Taleex Road');
          await tester.enterText(fields.at(3), 'Hodan');
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
        submitButton: find.textContaining('Confirm demo order'),
        build: (pending) async {
          final controller = await buildLoadedPharmacyController(
            orderRepository: _PendingPharmacyOrderRepository(pending),
          );
          controller.addProduct(controller.products.first);
          return PharmacyCheckoutScreen(controller: controller);
        },
        fillForm: (tester) async {
          const fields = {
            'pharmacy-customer-name': 'Asha Ali',
            'pharmacy-phone': '+252 61 234 5678',
            'pharmacy-district': 'Hodan',
            'pharmacy-address': 'Taleex Road, blue gate',
          };
          for (final MapEntry(:key, :value) in fields.entries) {
            await tester.enterText(find.byKey(ValueKey(key)), value);
          }
        },
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
        await tester.tap(c.submitButton);
        await tester.pump();
        expect(find.text('Saving order...'), findsOneWidget);

        await tester.tap(find.text('Saving order...'));
        await tester.pump();

        // Only one request ever reached the repository — the button was
        // disabled for the second tap, and the controller's own
        // `isSubmitting` guard is a second line of defense either way. The
        // first submission is left in flight (never completed) so this test
        // doesn't also have to stand up routes for the post-success
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
    required this.submitButton,
    required this.build,
    required this.fillForm,
  });

  final String service;
  final Finder submitButton;
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
