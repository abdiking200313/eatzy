import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/services/food/presentation/checkout_screen.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/food/data/food_repository.dart';
import 'package:chowflow/services/food/models/food_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

/// A [FoodOrderRepository] fake that always fails, simulating a network
/// error, Supabase exception, or RPC validation error surfaced when placing
/// a food order.
class _ThrowingFoodOrderRepository implements FoodOrderRepository {
  const _ThrowingFoodOrderRepository();

  @override
  Future<String> placeOrder(FoodOrderRequest request) {
    throw Exception('Simulated network failure while placing food order');
  }
}

void main() {
  const burger = CartItem(
    menuItemId: 'burger-1',
    restaurantId: 'restaurant-1',
    restaurantName: 'Test Kitchen',
    name: 'Classic Burger',
    unitPrice: 10,
    imageUrl: '',
  );

  testWidgets(
    'placing an order surfaces an error, resets the submit button, and '
    'keeps the cart when the order repository throws',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cartController = CartController(storage: MemoryCartStorage());
      await cartController.loadForOwner('user-1');
      await cartController.addItem(burger);
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

      expect(find.text('Place order'), findsOneWidget);

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
      expect(cartController.isEmpty, isFalse);
      expect(cartController.items, hasLength(1));
      expect(cartController.items.single.menuItemId, burger.menuItemId);

      // No activity should have been recorded for the failed order.
      expect(activityController.items, isEmpty);
    },
  );
}
