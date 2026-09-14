import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/platform/localization/app_money.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_cart_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/controllers.dart';

/// `PharmacyCartScreen` had zero widget-level test coverage until this file
/// (issue #18) — only its catalog screen (`PharmacyCatalogScreen`) and
/// `PharmacyCheckoutScreen` were previously exercised.
void main() {
  testWidgets(
    'renders seeded cart items, the OTC reminder, and totals, with a Clear '
    'action',
    (tester) async {
      final controller = await buildLoadedPharmacyController();
      final paracetamol = controller.products.firstWhere(
        (product) => product.id == 'pain-paracetamol',
      );
      final bandages = controller.products.firstWhere(
        (product) => product.id == 'first-aid-bandages',
      );
      controller.addProduct(paracetamol);
      controller.addProduct(bandages);

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

      await tester.scrollUntilVisible(
        find.text('Continue to checkout'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text(AppMoney.formatCents(600)), findsOneWidget);
      expect(find.text('Delivery in Somalia'), findsOneWidget);
      expect(find.text(AppMoney.formatCents(250)), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text(AppMoney.formatCents(850)), findsOneWidget);

      expect(find.text('Continue to checkout'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'increasing and decreasing an item updates its total and the cart '
    'subtotal',
    (tester) async {
      final controller = await buildLoadedPharmacyController();
      final paracetamol = controller.products.firstWhere(
        (product) => product.id == 'pain-paracetamol',
      );
      final bandages = controller.products.firstWhere(
        (product) => product.id == 'first-aid-bandages',
      );
      // Two items so a per-item total never happens to equal the cart
      // subtotal/total, keeping every `find.text` below unambiguous.
      controller.addProduct(paracetamol);
      controller.addProduct(bandages);

      await tester.pumpWidget(
        MaterialApp(home: PharmacyCartScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppMoney.formatCents(275)), findsOneWidget);
      expect(find.text(AppMoney.formatCents(600)), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('increase-pharmacy-pain-paracetamol')),
      );
      await tester.pumpAndSettle();

      expect(
        controller.cartItems
            .firstWhere((item) => item.product.id == 'pain-paracetamol')
            .quantity,
        2,
      );
      expect(find.text(AppMoney.formatCents(550)), findsOneWidget);
      expect(find.text(AppMoney.formatCents(875)), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('decrease-pharmacy-pain-paracetamol')),
      );
      await tester.pumpAndSettle();

      expect(
        controller.cartItems
            .firstWhere((item) => item.product.id == 'pain-paracetamol')
            .quantity,
        1,
      );
      expect(find.text(AppMoney.formatCents(275)), findsOneWidget);
      expect(find.text(AppMoney.formatCents(600)), findsOneWidget);
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
        find.byKey(const ValueKey('decrease-pharmacy-pain-paracetamol')),
      );
      await tester.pumpAndSettle();

      expect(controller.isCartEmpty, isTrue);
      expect(find.text('Your pharmacy cart is empty'), findsOneWidget);
      // The Clear action only makes sense with a non-empty cart.
      expect(find.text('Clear'), findsNothing);
    },
  );

  testWidgets('tapping Clear empties the cart and shows the empty state', (
    tester,
  ) async {
    final controller = await buildLoadedPharmacyController();
    controller.addProduct(controller.products.first);

    await tester.pumpWidget(
      MaterialApp(home: PharmacyCartScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(controller.isCartEmpty, isTrue);
    expect(find.text('Your pharmacy cart is empty'), findsOneWidget);
  });

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

      final increaseButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('increase-pharmacy-cold-cough-syrup')),
          matching: find.byType(IconButton),
        ),
      );
      expect(increaseButton.onPressed, isNull);

      // Tapping a disabled button is a no-op — the quantity must not move.
      await tester.tap(
        find.byKey(const ValueKey('increase-pharmacy-cold-cough-syrup')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(controller.cartItems.single.quantity, 4);
    },
  );

  testWidgets(
    'an empty cart shows a browse-pharmacy empty state with no checkout '
    'button, and Browse pharmacy navigates back to the catalog',
    (tester) async {
      final controller = await buildLoadedPharmacyController();

      final router = GoRouter(
        initialLocation: AppRoutes.pharmacyCart,
        routes: [
          GoRoute(
            path: AppRoutes.pharmacyCart,
            builder: (_, _) => PharmacyCartScreen(controller: controller),
          ),
          GoRoute(
            path: AppRoutes.pharmacy,
            builder: (_, _) => const Scaffold(body: Text('pharmacy-catalog')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Your pharmacy cart is empty'), findsOneWidget);
      expect(find.text('Continue to checkout'), findsNothing);

      await tester.tap(find.text('Browse pharmacy'));
      await tester.pumpAndSettle();

      expect(find.text('pharmacy-catalog'), findsOneWidget);
    },
  );

  testWidgets('tapping continue navigates to pharmacy checkout', (
    tester,
  ) async {
    final controller = await buildLoadedPharmacyController();
    controller.addProduct(controller.products.first);

    final router = GoRouter(
      initialLocation: AppRoutes.pharmacyCart,
      routes: [
        GoRoute(
          path: AppRoutes.pharmacyCart,
          builder: (_, _) => PharmacyCartScreen(controller: controller),
        ),
        GoRoute(
          path: AppRoutes.pharmacyCheckout,
          builder: (_, _) => PharmacyCheckoutScreen(controller: controller),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Continue to checkout'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Continue to checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Pharmacy checkout'), findsOneWidget);
  });
}
