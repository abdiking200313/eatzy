import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/food/data/food_repository.dart';
import 'package:chowflow/services/food/models/food_models.dart';
import 'package:chowflow/services/food/presentation/food_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

const _testAddress = FoodDeliveryAddress(
  recipientName: 'Amina Yusuf',
  phone: '+252 61 234 5678',
  street: 'Maka Al-Mukarama Road',
  district: 'Hodan',
  city: 'Mogadishu',
);

void main() {
  late CartController cartController;
  late ActivityController activityController;

  setUp(() async {
    cartController = CartController(storage: MemoryCartStorage());
    activityController = ActivityController();
    await cartController.loadForOwner('user-1');
  });

  Future<void> addBurger() => cartController
      .addItem(
        const CartItem(
          menuItemId: 'burger-1',
          restaurantId: 'restaurant-1',
          restaurantName: 'Test Kitchen',
          name: 'Classic Burger',
          unitPrice: 10,
          imageUrl: '',
        ),
      )
      .then((_) {});

  test('confirmOrder is a no-op when the cart is empty', () async {
    final controller = FoodController(
      cartController: cartController,
      orderRepository: const _FakeFoodOrderRepository(),
      activityController: activityController,
    );

    final result = await controller.confirmOrder(_testAddress);

    expect(result.isSuccess, isFalse);
    expect(controller.isSubmitting, isFalse);
    expect(controller.submissionError, isNull);
  });

  test(
    'confirmOrder places the order, records activity, and clears the cart',
    () async {
      await addBurger();
      final controller = FoodController(
        cartController: cartController,
        orderRepository: const _FakeFoodOrderRepository(),
        activityController: activityController,
      );

      final result = await controller.confirmOrder(_testAddress);

      expect(result.isSuccess, isTrue);
      expect(result.orderId, 'food-test-order');
      expect(controller.isSubmitting, isFalse);
      expect(controller.submissionError, isNull);
      expect(cartController.isEmpty, isTrue);
      expect(activityController.items.single.title, 'Test Kitchen');
    },
  );

  test('confirmOrder surfaces a message when the repository throws', () async {
    await addBurger();
    final controller = FoodController(
      cartController: cartController,
      orderRepository: const _FailingFoodOrderRepository(),
      activityController: activityController,
    );

    final result = await controller.confirmOrder(_testAddress);

    expect(result.isSuccess, isFalse);
    expect(
      result.errors.single,
      'The food order could not be saved. Please try again.',
    );
    expect(controller.submissionError, result.errors.single);
    expect(controller.isSubmitting, isFalse);
    expect(cartController.isEmpty, isFalse);
    expect(activityController.items, isEmpty);
  });
}

class _FakeFoodOrderRepository implements FoodOrderRepository {
  const _FakeFoodOrderRepository();

  @override
  Future<String> placeOrder(FoodOrderRequest request) async =>
      'food-test-order';
}

class _FailingFoodOrderRepository implements FoodOrderRepository {
  const _FailingFoodOrderRepository();

  @override
  Future<String> placeOrder(FoodOrderRequest request) async {
    throw Exception('network error');
  }
}
