import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/localization/app_money.dart';
import 'package:chowflow/services/food/data/food_repository.dart';
import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/models/food_models.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/services/food/presentation/checkout_screen.dart';
import 'package:chowflow/services/food/presentation/food_cart_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_cart_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_checkout_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_cart_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import 'package:chowflow/services/shared/data/rpc_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/controllers.dart';
import 'helpers/memory_cart_storage.dart';

/// Cart screens for every vertical: food, grocery, pharmacy. Behavior that is
/// the same across grocery and pharmacy (empty state, continue to checkout)
/// is table-driven in the `shared cart behavior` group.
void main() {
  group('food cart', () {
    const burger = CartItem(
      menuItemId: 'burger-1',
      restaurantId: 'restaurant-1',
      restaurantName: 'Test Kitchen',
      name: 'Classic Burger',
      unitPrice: 1000,
      imageUrl: '',
    );

    testWidgets('cart screen updates quantities, totals, and removes items', (
      tester,
    ) async {
      final controller = CartController(storage: MemoryCartStorage());
      await controller.loadForOwner('user-1');
      await controller.addItem(burger);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: CartScreen(cartController: controller),
        ),
      );

      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.text(r'$15.99'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('increase-cart-item-burger-1')),
      );
      await tester.pumpAndSettle();

      expect(controller.items.single.quantity, 2);
      expect(find.text(r'$26.99'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('remove-cart-item-burger-1')));
      await tester.pumpAndSettle();

      expect(controller.isEmpty, isTrue);
      expect(find.text('Your cart is empty'), findsOneWidget);
    });

    testWidgets('checkout places an order that is paid on delivery', (
      tester,
    ) async {
      final controller = CartController(storage: MemoryCartStorage());
      ActivityController.instance.clear();
      addTearDown(ActivityController.instance.clear);
      await controller.loadForOwner('user-1');
      await controller.addItem(burger);

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
            builder: (_, _) =>
                const Scaffold(body: Text('Activity destination')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      );

      expect(find.text('Classic Burger ×1'), findsOneWidget);
      expect(find.text(r'$15.99'), findsOneWidget);
      expect(find.text('Pay on delivery'), findsOneWidget);

      await tester.tap(find.byKey(const Key('checkout-place-order')));
      await tester.pumpAndSettle();
      expect(find.text('Order placed'), findsOneWidget);
      await tester.tap(find.text('View activity'));
      await tester.pumpAndSettle();

      expect(find.text('Activity destination'), findsOneWidget);
      expect(controller.isEmpty, isTrue);
      expect(ActivityController.instance.items.single.title, 'Test Kitchen');
    });
  });

  group('grocery cart', () {
    testWidgets(
      'renders lines with totals, and increase/decrease updates the line '
      'total and the cart subtotal',
      (tester) async {
        final controller = await buildLoadedGroceryController();
        final products = controller.stores
            .firstWhere((store) => store.id == 'bakaal-fresh')
            .products;
        // Two lines so a per-line total never happens to equal the cart
        // subtotal/total, keeping every `find.text` below unambiguous.
        controller.addProduct(
          products.firstWhere((product) => product.id == 'bakaal-rice'),
        );
        controller.addProduct(
          products.firstWhere((product) => product.id == 'bakaal-milk'),
        );

        await tester.pumpWidget(
          MaterialApp(home: GroceryCartScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bakaal Fresh'), findsOneWidget);
        expect(find.text('Basmati rice'), findsOneWidget);
        expect(find.text('Long-life milk'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(850)), findsOneWidget);
        expect(find.text('Subtotal'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(975)), findsOneWidget);
        expect(find.text('Delivery fee'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(250)), findsOneWidget);
        expect(find.text('Total'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(1225)), findsOneWidget);
        expect(find.byKey(const Key('cart-checkout')), findsOneWidget);
        expect(tester.takeException(), isNull);

        num riceQuantity() => controller.cart
            .firstWhere((line) => line.product.id == 'bakaal-rice')
            .quantity;

        await tester.tap(find.byTooltip('Increase Basmati rice'));
        await tester.pumpAndSettle();

        expect(riceQuantity(), 2);
        expect(find.text(AppMoney.formatCents(1700)), findsOneWidget);
        expect(find.text(AppMoney.formatCents(1825)), findsOneWidget);

        await tester.tap(find.byTooltip('Decrease Basmati rice'));
        await tester.pumpAndSettle();

        expect(riceQuantity(), 1);
        expect(find.text(AppMoney.formatCents(850)), findsOneWidget);
        expect(find.text(AppMoney.formatCents(975)), findsOneWidget);
      },
    );

    testWidgets('removing the only line in the cart shows the empty state', (
      tester,
    ) async {
      final controller = await buildLoadedGroceryController();
      controller.addProduct(
        controller.stores
            .expand((store) => store.products)
            .firstWhere((product) => product.id == 'bakaal-rice'),
      );

      await tester.pumpWidget(
        MaterialApp(home: GroceryCartScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('remove-cart-item-bakaal-rice')),
      );
      await tester.pumpAndSettle();

      expect(controller.isEmpty, isTrue);
      expect(find.text('Your grocery cart is empty'), findsOneWidget);
    });

    testWidgets(
      'increasing past available stock shows a snack bar and leaves the '
      'quantity capped',
      (tester) async {
        final controller = await buildLoadedGroceryController();
        final milk = controller.stores
            .expand((store) => store.products)
            .firstWhere((product) => product.id == 'bakaal-milk');
        controller.addProduct(milk);
        // `bakaal-milk` is seeded with `availableQuantity: 3` — already at
        // the stock ceiling before the test taps "increase".
        controller.setQuantity(milk.id, 3);

        await tester.pumpWidget(
          MaterialApp(home: GroceryCartScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Increase Long-life milk'));
        await tester.pumpAndSettle();

        expect(
          find.text('No more Long-life milk is available.'),
          findsOneWidget,
        );
        expect(controller.cart.single.quantity, 3);
      },
    );
  });

  group('pharmacy cart', () {
    testWidgets(
      'renders items, the OTC reminder and totals; increase/decrease updates '
      'totals; Clear empties the cart',
      (tester) async {
        final controller = await buildLoadedPharmacyController();
        // Two items so a per-item total never happens to equal the cart
        // subtotal/total, keeping every `find.text` below unambiguous.
        controller.addProduct(
          controller.products.firstWhere(
            (product) => product.id == 'pain-paracetamol',
          ),
        );
        controller.addProduct(
          controller.products.firstWhere(
            (product) => product.id == 'first-aid-bandages',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: PharmacyCartScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('separate from food and grocery'),
          findsOneWidget,
        );
        expect(find.text('Paracetamol'), findsOneWidget);
        expect(find.text('Adhesive Bandages'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(275)), findsOneWidget);

        int paracetamolQuantity() => controller.cartItems
            .firstWhere((item) => item.product.id == 'pain-paracetamol')
            .quantity;

        await tester.tap(
          find.byKey(const ValueKey('increase-cart-item-pain-paracetamol')),
        );
        await tester.pumpAndSettle();

        expect(paracetamolQuantity(), 2);
        expect(find.text(AppMoney.formatCents(550)), findsOneWidget);
        expect(find.text(AppMoney.formatCents(875)), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('decrease-cart-item-pain-paracetamol')),
        );
        await tester.pumpAndSettle();

        expect(paracetamolQuantity(), 1);

        expect(find.text('Subtotal'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(600)), findsOneWidget);
        expect(find.text('Delivery fee'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(250)), findsOneWidget);
        expect(find.text('Total'), findsOneWidget);
        expect(find.text(AppMoney.formatCents(850)), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear cart'));
        await tester.pumpAndSettle();

        expect(controller.isCartEmpty, isTrue);
        expect(find.text('Your pharmacy cart is empty'), findsOneWidget);
      },
    );

    testWidgets(
      'decrementing the only unit of an item removes it and shows the empty '
      'state',
      (tester) async {
        final controller = await buildLoadedPharmacyController();
        controller.addProduct(
          controller.products.firstWhere(
            (product) => product.id == 'pain-paracetamol',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: PharmacyCartScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('decrease-cart-item-pain-paracetamol')),
        );
        await tester.pumpAndSettle();

        expect(controller.isCartEmpty, isTrue);
        expect(find.text('Your pharmacy cart is empty'), findsOneWidget);
        // The Clear action only makes sense with a non-empty cart.
        expect(find.text('Clear'), findsNothing);
      },
    );

    testWidgets(
      'an item already at its stock ceiling disables the increase button '
      'instead of over-adding it',
      (tester) async {
        final controller = await buildLoadedPharmacyController();
        // `cold-cough-syrup` is seeded with `stockQuantity: 4`.
        final coughSyrup = controller.products.firstWhere(
          (product) => product.id == 'cold-cough-syrup',
        );
        controller.addProduct(coughSyrup);
        controller.increment(coughSyrup.id);
        controller.increment(coughSyrup.id);
        controller.increment(coughSyrup.id);
        expect(controller.cartItems.single.quantity, 4);

        await tester.pumpWidget(
          MaterialApp(home: PharmacyCartScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        final increase = find.byKey(
          const ValueKey('increase-cart-item-cold-cough-syrup'),
        );
        final increaseButton = tester.widget<IconButton>(
          find.descendant(of: increase, matching: find.byType(IconButton)),
        );
        expect(increaseButton.onPressed, isNull);

        // Tapping a disabled button is a no-op — the quantity must not move.
        await tester.tap(increase, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(controller.cartItems.single.quantity, 4);
      },
    );
  });

  group('shared cart behavior', () {
    final cases = <_CartCase>[
      _CartCase(
        service: 'grocery',
        cartRoute: AppRoutes.groceryCart,
        catalogRoute: AppRoutes.grocery,
        checkoutRoute: AppRoutes.groceryCheckout,
        emptyTitle: 'Your grocery cart is empty',
        browseLabel: 'Browse stores',
        continueButton: find.byKey(const Key('cart-checkout')),
        checkoutTitle: 'Grocery checkout',
        build: ({required fillCart}) async {
          final controller = await buildLoadedGroceryController();
          if (fillCart) {
            controller.addProduct(
              controller.stores
                  .expand((store) => store.products)
                  .firstWhere((product) => product.id == 'bakaal-rice'),
            );
          }
          return (
            cart: GroceryCartScreen(controller: controller),
            checkout: GroceryCheckoutScreen(controller: controller),
          );
        },
      ),
      _CartCase(
        service: 'pharmacy',
        cartRoute: AppRoutes.pharmacyCart,
        catalogRoute: AppRoutes.pharmacy,
        checkoutRoute: AppRoutes.pharmacyCheckout,
        emptyTitle: 'Your pharmacy cart is empty',
        browseLabel: 'Browse pharmacy',
        continueButton: find.byKey(const Key('cart-checkout')),
        checkoutTitle: 'Checkout',
        build: ({required fillCart}) async {
          final controller = await buildLoadedPharmacyController();
          if (fillCart) controller.addProduct(controller.products.first);
          return (
            cart: PharmacyCartScreen(controller: controller),
            checkout: PharmacyCheckoutScreen(controller: controller),
          );
        },
      ),
    ];

    for (final c in cases) {
      testWidgets('${c.service}: an empty cart has no checkout button, and '
          '"${c.browseLabel}" navigates back to the catalog', (tester) async {
        final screens = await c.build(fillCart: false);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: c.cartRoute,
              routes: [
                GoRoute(path: c.cartRoute, builder: (_, _) => screens.cart),
                GoRoute(
                  path: c.catalogRoute,
                  builder: (_, _) =>
                      const Scaffold(body: Text('catalog-destination')),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(c.emptyTitle), findsOneWidget);
        expect(c.continueButton, findsNothing);

        await tester.tap(find.text(c.browseLabel));
        await tester.pumpAndSettle();

        expect(find.text('catalog-destination'), findsOneWidget);
      });

      testWidgets('${c.service}: tapping continue navigates to checkout', (
        tester,
      ) async {
        final screens = await c.build(fillCart: true);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: c.cartRoute,
              routes: [
                GoRoute(path: c.cartRoute, builder: (_, _) => screens.cart),
                GoRoute(
                  path: c.checkoutRoute,
                  builder: (_, _) => screens.checkout,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(c.continueButton);
        await tester.pumpAndSettle();

        expect(find.text(c.checkoutTitle), findsOneWidget);
      });
    }
  });
}

class _CartCase {
  const _CartCase({
    required this.service,
    required this.cartRoute,
    required this.catalogRoute,
    required this.checkoutRoute,
    required this.emptyTitle,
    required this.browseLabel,
    required this.continueButton,
    required this.checkoutTitle,
    required this.build,
  });

  final String service;
  final String cartRoute;
  final String catalogRoute;
  final String checkoutRoute;
  final String emptyTitle;
  final String browseLabel;
  final Finder continueButton;
  final String checkoutTitle;
  final Future<({Widget cart, Widget checkout})> Function({
    required bool fillCart,
  })
  build;
}

class _FakeFoodOrderRepository implements FoodOrderRepository {
  const _FakeFoodOrderRepository();

  @override
  Future<PlacedOrder> placeOrder(FoodOrderRequest request) async =>
      const PlacedOrder(
        orderId: 'food-test-order',
        subtotal: 1000,
        deliveryFee: 499,
        tax: 100,
        total: 1599,
      );
}
