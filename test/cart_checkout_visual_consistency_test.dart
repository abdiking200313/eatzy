import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/services/food/presentation/checkout_screen.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/food/presentation/food_cart_screen.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_cart_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_checkout_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_cart_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

/// Redesign phase 5 (#26) DoD: a 320x640 @1.4x-text-scale no-overflow case
/// for every cart/checkout screen this phase touches, verifying the merged
/// "one card per list" layouts don't overflow with a long item name and
/// enlarged text.
void main() {
  Widget wrapped(Widget child, {ServiceId? serviceId}) {
    final themed = serviceId == null
        ? child
        : ZivoServiceTheme(serviceId: serviceId, child: child);
    return MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.4),
        ),
        child: themed,
      ),
    );
  }

  Future<void> pumpNarrow(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  testWidgets('food cart stays overflow-free on a narrow, large-text screen', (
    tester,
  ) async {
    final controller = CartController(storage: MemoryCartStorage());
    await controller.loadForOwner('user-1');
    await controller.addItem(
      const CartItem(
        menuItemId: 'burger-1',
        restaurantId: 'restaurant-1',
        restaurantName: 'Test Kitchen',
        name: 'Deluxe Double Cheese Smoked Beef Burger Combo',
        unitPrice: 10,
        imageUrl: '',
      ),
    );

    await pumpNarrow(tester, wrapped(CartScreen(cartController: controller)));

    expect(
      find.text('Deluxe Double Cheese Smoked Beef Burger Combo'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'food checkout stays overflow-free on a narrow, large-text screen',
    (tester) async {
      final controller = CartController(storage: MemoryCartStorage());
      await controller.loadForOwner('user-1');
      await controller.addItem(
        const CartItem(
          menuItemId: 'burger-1',
          restaurantId: 'restaurant-1',
          restaurantName: 'Test Kitchen',
          name: 'Deluxe Double Cheese Smoked Beef Burger Combo',
          unitPrice: 10,
          imageUrl: '',
        ),
      );

      await pumpNarrow(
        tester,
        wrapped(CheckoutScreen(cartController: controller)),
      );

      expect(find.text('Order Summary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grocery cart stays overflow-free on a narrow, large-text screen',
    (tester) async {
      final controller = GroceryController(
        repository: const SeededGroceryRepository(),
        activityController: ActivityController(),
        storage: MemoryCartStorage<GroceryCartLine>(),
      );
      await controller.load();
      final products = controller.stores
          .expand((store) => store.products)
          .where((product) => product.isAvailable)
          .take(2)
          .toList();
      for (final product in products) {
        controller.addProduct(product);
      }

      await pumpNarrow(
        tester,
        wrapped(
          GroceryCartScreen(controller: controller),
          serviceId: ServiceId.grocery,
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grocery checkout stays overflow-free on a narrow, large-text screen',
    (tester) async {
      final controller = GroceryController(
        repository: const SeededGroceryRepository(),
        activityController: ActivityController(),
        storage: MemoryCartStorage<GroceryCartLine>(),
      );
      await controller.load();
      final product = controller.stores
          .expand((store) => store.products)
          .firstWhere((product) => product.isAvailable);
      controller.addProduct(product);

      await pumpNarrow(
        tester,
        wrapped(
          GroceryCheckoutScreen(controller: controller),
          serviceId: ServiceId.grocery,
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Delivery slot'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Total (USD)'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pharmacy cart stays overflow-free on a narrow, large-text screen',
    (tester) async {
      final controller = PharmacyController(
        repository: const SeededPharmacyRepository(),
        activityController: ActivityController(),
        storage: MemoryCartStorage<PharmacyCartItem>(),
      );
      await controller.loadProducts();
      for (final product in controller.products.take(2)) {
        controller.addProduct(product);
      }

      await pumpNarrow(
        tester,
        wrapped(
          PharmacyCartScreen(controller: controller),
          serviceId: ServiceId.pharmacy,
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pharmacy checkout stays overflow-free on a narrow, large-text screen',
    (tester) async {
      final controller = PharmacyController(
        repository: const SeededPharmacyRepository(),
        activityController: ActivityController(),
        storage: MemoryCartStorage<PharmacyCartItem>(),
      );
      await controller.loadProducts();
      controller.addProduct(controller.products.first);

      await pumpNarrow(
        tester,
        wrapped(
          PharmacyCheckoutScreen(controller: controller),
          serviceId: ServiceId.pharmacy,
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Order summary'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
