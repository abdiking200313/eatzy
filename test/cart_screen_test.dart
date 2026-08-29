import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/cart/models/cart_item.dart';
import 'package:chowflow/features/cart/presentation/cart_controller.dart';
import 'package:chowflow/features/checkout/presentation/checkout_screen.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/food/data/food_repository.dart';
import 'package:chowflow/services/food/models/food_models.dart';
import 'package:chowflow/screens/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  testWidgets('cart screen updates quantities, totals, and removes items', (
    tester,
  ) async {
    final controller = CartController(storage: MemoryCartStorage());
    await controller.loadForOwner('user-1');
    await controller.addItem(
      const CartItem(
        menuItemId: 'burger-1',
        restaurantId: 'restaurant-1',
        restaurantName: 'Test Kitchen',
        name: 'Classic Burger',
        unitPrice: 10,
        imageUrl: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: CartScreen(cartController: controller),
      ),
    );

    expect(find.text('Classic Burger'), findsOneWidget);
    expect(find.text(r'$15.99'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('increase-cart-item-burger-1')));
    await tester.pumpAndSettle();

    expect(controller.items.single.quantity, 2);
    expect(find.text(r'$26.99'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-cart-item-burger-1')));
    await tester.pumpAndSettle();

    expect(controller.isEmpty, isTrue);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('checkout records a demo order without processing payment', (
    tester,
  ) async {
    final controller = CartController(storage: MemoryCartStorage());
    ActivityController.instance.clear();
    addTearDown(ActivityController.instance.clear);
    await controller.loadForOwner('user-1');
    await controller.addItem(
      const CartItem(
        menuItemId: 'burger-1',
        restaurantId: 'restaurant-1',
        restaurantName: 'Test Kitchen',
        name: 'Classic Burger',
        unitPrice: 10,
        imageUrl: '',
      ),
    );

    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (_, _) => CheckoutScreen(
            cartController: controller,
            orderRepository: const _FakeFoodOrderRepository(),
          ),
        ),
        GoRoute(
          path: '/activity',
          builder: (_, _) => const Scaffold(body: Text('Activity destination')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );

    expect(find.text('Classic Burger'), findsOneWidget);
    expect(find.text(r'$15.99'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('food-recipient-name')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-recipient-name')),
      'Amina Yusuf',
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-phone')),
      '+252611234567',
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-street')),
      'Maka Al-Mukarama Road',
    );
    await tester.enterText(
      find.byKey(const ValueKey('food-district')),
      'Hodan',
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Place demo order'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Place demo order'), findsOneWidget);

    await tester.tap(find.text('Place demo order'));
    await tester.pumpAndSettle();

    expect(find.text('Activity destination'), findsOneWidget);
    expect(controller.isEmpty, isTrue);
    expect(ActivityController.instance.items.single.title, 'Test Kitchen');
  });
}

class _FakeFoodOrderRepository implements FoodOrderRepository {
  const _FakeFoodOrderRepository();

  @override
  Future<String> placeOrder(FoodOrderRequest request) async =>
      'food-test-order';
}
