import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/cart/models/cart_item.dart';
import 'package:chowflow/features/cart/presentation/cart_controller.dart';
import 'package:chowflow/features/checkout/presentation/checkout_screen.dart';
import 'package:chowflow/screens/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('checkout uses the live cart and stops before payment', (
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
        home: CheckoutScreen(cartController: controller),
      ),
    );

    expect(find.text('Classic Burger'), findsOneWidget);
    expect(find.text(r'$15.99'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Continue to payment'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Continue to payment'), findsOneWidget);

    await tester.tap(find.text('Continue to payment'));
    await tester.pump();

    expect(
      find.text('Payment will be connected in the next step.'),
      findsOneWidget,
    );
  });
}
