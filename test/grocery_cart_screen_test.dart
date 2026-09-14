import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/platform/localization/app_money.dart';
import 'package:chowflow/services/grocery/presentation/grocery_cart_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/controllers.dart';

/// `GroceryCartScreen` had zero widget-level test coverage until this file
/// (issue #18) — only its catalog screens (`GroceryScreen`/
/// `GroceryStoreScreen`) and `GroceryCheckoutScreen` were previously
/// exercised.
void main() {
  testWidgets('renders seeded cart lines with per-line quantities and totals', (
    tester,
  ) async {
    final controller = await buildLoadedGroceryController();
    final products = controller.stores
        .firstWhere((store) => store.id == 'bakaal-fresh')
        .products;
    final rice = products.firstWhere((product) => product.id == 'bakaal-rice');
    final milk = products.firstWhere((product) => product.id == 'bakaal-milk');
    controller.addProduct(rice);
    controller.addProduct(milk);

    await tester.pumpWidget(
      MaterialApp(home: GroceryCartScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bakaal Fresh'), findsOneWidget);
    expect(find.text('Basmati rice'), findsOneWidget);
    expect(find.text('Long-life milk'), findsOneWidget);

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(AppMoney.formatCents(975)), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text(AppMoney.formatCents(250)), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(AppMoney.formatCents(1225)), findsOneWidget);

    expect(find.textContaining('Continue •'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('increasing and decreasing a line updates its total and the cart '
      'subtotal', (tester) async {
    final controller = await buildLoadedGroceryController();
    final products = controller.stores
        .firstWhere((store) => store.id == 'bakaal-fresh')
        .products;
    final rice = products.firstWhere((product) => product.id == 'bakaal-rice');
    final milk = products.firstWhere((product) => product.id == 'bakaal-milk');
    // Two lines so a per-line total never happens to equal the cart
    // subtotal/total, keeping every `find.text` below unambiguous.
    controller.addProduct(rice);
    controller.addProduct(milk);

    await tester.pumpWidget(
      MaterialApp(home: GroceryCartScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppMoney.formatCents(850)), findsOneWidget);
    expect(find.text(AppMoney.formatCents(975)), findsOneWidget);

    await tester.tap(find.byTooltip('Increase Basmati rice'));
    await tester.pumpAndSettle();

    expect(
      controller.cart
          .firstWhere((line) => line.product.id == 'bakaal-rice')
          .quantity,
      2,
    );
    expect(find.text(AppMoney.formatCents(1700)), findsOneWidget);
    expect(find.text(AppMoney.formatCents(1825)), findsOneWidget);

    await tester.tap(find.byTooltip('Decrease Basmati rice'));
    await tester.pumpAndSettle();

    expect(
      controller.cart
          .firstWhere((line) => line.product.id == 'bakaal-rice')
          .quantity,
      1,
    );
    expect(find.text(AppMoney.formatCents(850)), findsOneWidget);
    expect(find.text(AppMoney.formatCents(975)), findsOneWidget);
  });

  testWidgets('removing the only line in the cart shows the empty state', (
    tester,
  ) async {
    final controller = await buildLoadedGroceryController();
    final rice = controller.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == 'bakaal-rice');
    controller.addProduct(rice);

    await tester.pumpWidget(
      MaterialApp(home: GroceryCartScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
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
      // `bakaal-milk` is seeded with `availableQuantity: 3` — already at the
      // stock ceiling before the test taps "increase".
      controller.setQuantity(milk.id, 3);

      await tester.pumpWidget(
        MaterialApp(home: GroceryCartScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Increase Long-life milk'));
      await tester.pumpAndSettle();

      expect(find.text('No more Long-life milk is available.'), findsOneWidget);
      expect(controller.cart.single.quantity, 3);
    },
  );

  testWidgets(
    'an empty cart shows a browse-groceries empty state with no checkout '
    'button, and Browse groceries navigates back to the catalog',
    (tester) async {
      final controller = await buildLoadedGroceryController();

      final router = GoRouter(
        initialLocation: AppRoutes.groceryCart,
        routes: [
          GoRoute(
            path: AppRoutes.groceryCart,
            builder: (_, _) => GroceryCartScreen(controller: controller),
          ),
          GoRoute(
            path: AppRoutes.grocery,
            builder: (_, _) => const Scaffold(body: Text('grocery-catalog')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Your grocery cart is empty'), findsOneWidget);
      expect(find.textContaining('Continue •'), findsNothing);

      await tester.tap(find.text('Browse groceries'));
      await tester.pumpAndSettle();

      expect(find.text('grocery-catalog'), findsOneWidget);
    },
  );

  testWidgets('tapping continue navigates to grocery checkout', (tester) async {
    final controller = await buildLoadedGroceryController();
    final rice = controller.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == 'bakaal-rice');
    controller.addProduct(rice);

    final router = GoRouter(
      initialLocation: AppRoutes.groceryCart,
      routes: [
        GoRoute(
          path: AppRoutes.groceryCart,
          builder: (_, _) => GroceryCartScreen(controller: controller),
        ),
        GoRoute(
          path: AppRoutes.groceryCheckout,
          builder: (_, _) => GroceryCheckoutScreen(controller: controller),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Continue •'));
    await tester.pumpAndSettle();

    expect(find.text('Grocery checkout'), findsOneWidget);
  });
}
