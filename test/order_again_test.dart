import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/data/order_again_repository.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/features/orders/presentation/track_order_screen.dart';
import 'package:chowflow/platform/activity/data/activity_repository.dart';
import 'package:chowflow/platform/activity/models/order_details.dart';
import 'package:chowflow/platform/activity/presentation/order_again_service.dart';
import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/controllers.dart';
import 'helpers/memory_cart_storage.dart';

void main() {
  const pastBurger = CartItem(
    menuItemId: 'burger-1',
    restaurantId: 'restaurant-1',
    restaurantName: 'Test Kitchen',
    name: 'Classic Burger',
    unitPrice: 1200,
    imageUrl: '',
    quantity: 2,
  );
  const otherRestaurantItem = CartItem(
    menuItemId: 'soup-9',
    restaurantId: 'restaurant-9',
    restaurantName: 'Other Place',
    name: 'Lentil Soup',
    unitPrice: 500,
    imageUrl: '',
  );

  late CartController foodCart;
  late GroceryController grocery;
  late PharmacyController pharmacy;

  setUp(() async {
    foodCart = CartController(storage: MemoryCartStorage());
    await foodCart.loadForOwner('user-1');
    grocery = await buildLoadedGroceryController();
    pharmacy = await buildLoadedPharmacyController();
  });

  OrderAgainService service(ReorderBasket? basket) => OrderAgainService(
    repository: _FakeOrderAgainRepository(basket),
    foodCart: foodCart,
    grocery: grocery,
    pharmacy: pharmacy,
  );

  group('OrderAgainService.fillCart', () {
    test(
      'food: replaces the cart with the past items at their quantities',
      () async {
        await foodCart.addItem(otherRestaurantItem);
        const basket = FoodReorderBasket(
          items: [pastBurger],
          skippedNames: ['Fries'],
        );

        expect(service(basket).wouldReplaceCart(basket), isTrue);
        final route = await service(basket).fillCart(basket);

        expect(route, AppRoutes.foodCart);
        expect(foodCart.items, hasLength(1));
        expect(foodCart.items.single.menuItemId, 'burger-1');
        expect(foodCart.items.single.quantity, 2);
        // Today's price, carried in the basket, is what the cart uses.
        expect(foodCart.subtotal, 2400);
      },
    );

    test('grocery: fills the grocery cart', () async {
      final rice = grocery.stores
          .expand((store) => store.products)
          .firstWhere((product) => product.id == 'bakaal-rice');
      final basket = GroceryReorderBasket(
        lines: [(product: rice, quantity: 3)],
        skippedNames: const [],
      );

      expect(service(basket).wouldReplaceCart(basket), isFalse);
      final route = await service(basket).fillCart(basket);

      expect(route, AppRoutes.groceryCart);
      expect(grocery.cart.single.product.id, 'bakaal-rice');
      expect(grocery.cart.single.quantity, 3);
    });

    test('pharmacy: fills the pharmacy cart', () async {
      final product = pharmacy.products.first;
      final basket = PharmacyReorderBasket(
        lines: [(product: product, quantity: 2)],
        skippedNames: const [],
      );

      final route = await service(basket).fillCart(basket);

      expect(route, AppRoutes.pharmacyCart);
      expect(pharmacy.cartItems.single.product.id, product.id);
      expect(pharmacy.cartItems.single.quantity, 2);
    });
  });

  group('Order details "Order again"', () {
    final foodOrder = ActivityItem(
      id: 'order-1',
      serviceId: ServiceId.food,
      title: 'Test Kitchen',
      status: 'Delivered',
      occurredAt: DateTime.utc(2026, 9, 20),
      amount: 2400,
      detailsRoute: AppRoutes.food,
    );
    final orderAgainButton = find.byKey(
      const ValueKey('order-details-order-again'),
    );

    /// Builds the food cart inside the widget test's own fake-async zone (a
    /// cart built in `setUp` awaits writes that never complete there),
    /// optionally pre-filled, and pumps the order details screen.
    Future<CartController> pumpOrderDetails(
      WidgetTester tester,
      ReorderBasket basket, {
      bool prefilled = false,
    }) async {
      final cart = CartController(storage: MemoryCartStorage());
      await cart.loadForOwner('user-1');
      if (prefilled) await cart.addItem(otherRestaurantItem);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: foodOrder.orderDetailsPath,
            routes: [
              GoRoute(
                path: AppRoutes.trackOrderDetails,
                builder: (_, state) => TrackOrderScreen(
                  orderId: state.pathParameters['orderId'],
                  serviceId: state.pathParameters['serviceId'],
                  repository: _FakeOrderDetailsRepository(
                    OrderDetails(
                      summary: foodOrder,
                      lines: const [
                        OrderLine(
                          name: 'Classic Burger',
                          quantity: 2,
                          unitPrice: 1200,
                        ),
                      ],
                      subtotal: 2400,
                      deliveryFee: 0,
                      total: 2400,
                    ),
                  ),
                  orderAgainService: OrderAgainService(
                    repository: _FakeOrderAgainRepository(basket),
                    foodCart: cart,
                    grocery: grocery,
                    pharmacy: pharmacy,
                  ),
                ),
              ),
              GoRoute(
                path: AppRoutes.foodCart,
                builder: (_, _) => const Scaffold(body: Text('food-cart')),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      return cart;
    }

    testWidgets('asks before replacing a non-empty cart, then fills it, '
        'lists skipped items and opens the cart', (tester) async {
      final cart = await pumpOrderDetails(
        tester,
        const FoodReorderBasket(items: [pastBurger], skippedNames: ['Fries']),
        prefilled: true,
      );

      await tester.tap(orderAgainButton);
      await tester.pumpAndSettle();
      expect(find.text('Replace your cart?'), findsOneWidget);

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(find.text('food-cart'), findsOneWidget);
      expect(find.text('No longer available: Fries'), findsOneWidget);
      expect(cart.items.single.menuItemId, 'burger-1');
    });

    testWidgets('cancelling the replace prompt leaves the cart alone', (
      tester,
    ) async {
      final cart = await pumpOrderDetails(
        tester,
        const FoodReorderBasket(items: [pastBurger], skippedNames: []),
        prefilled: true,
      );

      await tester.tap(orderAgainButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('food-cart'), findsNothing);
      expect(cart.items.single.menuItemId, 'soup-9');
    });

    testWidgets('an empty cart is filled without asking', (tester) async {
      await pumpOrderDetails(
        tester,
        const FoodReorderBasket(items: [pastBurger], skippedNames: []),
      );

      await tester.tap(orderAgainButton);
      await tester.pumpAndSettle();

      expect(find.text('Replace your cart?'), findsNothing);
      expect(find.text('food-cart'), findsOneWidget);
    });

    testWidgets('when nothing is available any more, says so and stays', (
      tester,
    ) async {
      final cart = await pumpOrderDetails(
        tester,
        const FoodReorderBasket(items: [], skippedNames: ['Classic Burger']),
      );

      await tester.tap(orderAgainButton);
      await tester.pumpAndSettle();

      expect(
        find.text('None of these items can be ordered right now.'),
        findsOneWidget,
      );
      expect(find.text('food-cart'), findsNothing);
      expect(cart.isEmpty, isTrue);
    });
  });
}

class _FakeOrderAgainRepository implements OrderAgainRepository {
  const _FakeOrderAgainRepository(this.basket);

  final ReorderBasket? basket;

  @override
  Future<ReorderBasket?> loadBasket({
    required ServiceId serviceId,
    required String orderId,
  }) async => basket;
}

class _FakeOrderDetailsRepository implements OrderDetailsRepository {
  const _FakeOrderDetailsRepository(this.order);

  final OrderDetails order;

  @override
  Future<ActivityItem?> fetchOrderById({
    required String orderId,
    required String serviceId,
  }) async => order.summary;

  @override
  Future<OrderDetails?> fetchOrderDetails({
    required String orderId,
    required String serviceId,
  }) async => order;
}
