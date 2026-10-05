import 'package:chowflow/app/app_router.dart';
import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/platform/activity/data/order_again_repository.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/activity/presentation/order_again_service.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_cart_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/memory_cart_storage.dart';

/// Grocery, Fresh Meat and Electronics share the grocery engine but each
/// has its own store list, cart, routes and palette (2026-09-25).
void main() {
  GroceryProduct product(String id, String storeId) => GroceryProduct(
    id: id,
    storeId: storeId,
    name: id,
    description: '',
    unitPrice: 500,
    pricingUnit: GroceryPricingUnit.each,
    stockState: GroceryStockState.inStock,
    availableQuantity: 10,
    icon: '🛒',
  );

  final mixedStores = _MixedStoresRepository([
    GroceryStore(
      id: 'bakaal',
      name: 'Bakaal',
      area: 'Hodan',
      products: [product('rice', 'bakaal')],
    ),
    GroceryStore(
      id: 'butcher',
      name: 'Hamar Meat',
      area: 'Hamar',
      storeType: GroceryStoreType.freshMeat,
      products: [product('goat', 'butcher')],
    ),
    GroceryStore(
      id: 'phones',
      name: 'Phone Hub',
      area: 'KM4',
      storeType: GroceryStoreType.electronics,
      products: [product('charger', 'phones')],
    ),
  ]);

  GroceryController controllerFor(GroceryStoreType type) => GroceryController(
    repository: mixedStores,
    storage: MemoryCartStorage<GroceryCartLine>(),
    activityController: ActivityController(),
    storeType: type,
  );

  test('each category controller lists only its own stores', () async {
    for (final (type, storeId) in [
      (GroceryStoreType.grocery, 'bakaal'),
      (GroceryStoreType.freshMeat, 'butcher'),
      (GroceryStoreType.electronics, 'phones'),
    ]) {
      final controller = controllerFor(type);
      await controller.load();
      expect(controller.stores.map((store) => store.id), [storeId]);
    }
  });

  test('carts are independent: a meat cart does not touch the grocery '
      'cart, and neither asks to replace the other', () async {
    final grocery = controllerFor(GroceryStoreType.grocery);
    final meat = controllerFor(GroceryStoreType.freshMeat);
    await grocery.load();
    await meat.load();

    expect(
      grocery.addProduct(product('rice', 'bakaal')),
      GroceryAddResult.added,
    );
    expect(meat.addProduct(product('goat', 'butcher')), GroceryAddResult.added);

    expect(grocery.cart.single.product.id, 'rice');
    expect(meat.cart.single.product.id, 'goat');
  });

  test('every category has its own registered list, store, cart and '
      'checkout routes', () {
    final paths = <String>{};
    for (final type in GroceryStoreType.values) {
      for (final path in [
        type.listRoute,
        type.storeRoutePattern,
        type.cartRoute,
        type.checkoutRoute,
      ]) {
        expect(AppRouter.hasRegisteredRoute(path), isTrue, reason: path);
        expect(paths.add(path), isTrue, reason: 'duplicate route $path');
      }
    }
    expect(
      GroceryStoreType.freshMeat.storeDetailsRoute('hamar meat'),
      '${AppRoutes.freshMeat}/stores/hamar%20meat',
    );
  });

  test('Fresh Meat and Electronics have their own palettes', () {
    final accents = {
      for (final type in GroceryStoreType.values) type.palette.accent,
    };
    expect(accents, hasLength(3));
    expect(GroceryStoreType.grocery.palette, ServiceThemes.grocery);
  });

  testWidgets('the Fresh Meat cart is titled and linked as Fresh Meat', (
    tester,
  ) async {
    final meat = controllerFor(GroceryStoreType.freshMeat);
    await meat.load();

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: GoRouter(
          initialLocation: AppRoutes.freshMeatCart,
          routes: [
            GoRoute(
              path: AppRoutes.freshMeatCart,
              builder: (_, _) => GroceryCartScreen(
                controller: meat,
                storeType: GroceryStoreType.freshMeat,
              ),
            ),
            GoRoute(
              path: AppRoutes.freshMeat,
              builder: (_, _) => const Scaffold(body: Text('meat-stores')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fresh Meat cart'), findsOneWidget);
    expect(find.text('Your fresh meat cart is empty'), findsOneWidget);

    await tester.tap(find.text('Browse stores'));
    await tester.pumpAndSettle();
    expect(find.text('meat-stores'), findsOneWidget);
  });

  test(
    'Order again puts a Fresh Meat order back into the Fresh Meat cart',
    () async {
      final meat = controllerFor(GroceryStoreType.freshMeat);
      await meat.load();
      final basket = GroceryReorderBasket(
        lines: [(product: product('goat', 'butcher'), quantity: 2)],
        skippedNames: const [],
        storeType: GroceryStoreType.freshMeat,
      );

      final route = await OrderAgainService(
        repository: _FixedBasket(basket),
        grocery: meat,
      ).fillCart(basket);

      expect(route, AppRoutes.freshMeatCart);
      expect(meat.cart.single.quantity, 2);
    },
  );
}

class _MixedStoresRepository implements GroceryRepository {
  const _MixedStoresRepository(this.stores);

  final List<GroceryStore> stores;

  @override
  Future<List<GroceryStore>> fetchStores() async => stores;
}

class _FixedBasket implements OrderAgainRepository {
  const _FixedBasket(this.basket);

  final ReorderBasket basket;

  @override
  Future<ReorderBasket?> loadBasket({
    required serviceId,
    required orderId,
  }) async => basket;
}
