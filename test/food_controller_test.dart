import 'dart:async';

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

  test('confirmOrder ignores a second call while a submission is in flight '
      '(issue #59)', () async {
    await addBurger();
    final repository = _ControllableFoodOrderRepository();
    final controller = FoodController(
      cartController: cartController,
      orderRepository: repository,
      activityController: activityController,
    );

    final first = controller.confirmOrder(_testAddress);
    expect(controller.isSubmitting, isTrue);

    // A second call while the first is still in flight must be a no-op:
    // it must not reach the repository and must not disturb the cart or
    // submission state the first call owns.
    final second = await controller.confirmOrder(_testAddress);
    expect(second.isSuccess, isFalse);
    expect(repository.callCount, 1);

    repository.complete('food-order-1');
    final result = await first;

    expect(result.isSuccess, isTrue);
    expect(repository.callCount, 1);
    expect(controller.isSubmitting, isFalse);
  });

  test(
    'confirmOrder forwards a caller-supplied idempotency key to the '
    'repository, and synthesizes one when none is given (issue #59)',
    () async {
      await addBurger();
      final repository = _RecordingFoodOrderRepository();
      final controller = FoodController(
        cartController: cartController,
        orderRepository: repository,
        activityController: activityController,
      );

      await controller.confirmOrder(
        _testAddress,
        idempotencyKey: 'attempt-key-1',
      );

      expect(repository.lastRequest!.idempotencyKey, 'attempt-key-1');

      // A second, independent attempt (cart repopulated after the first
      // order cleared it) with no key supplied still gets a non-empty key
      // generated for it, so the RPC always has one to key its own
      // de-duplication on.
      await addBurger();
      await controller.confirmOrder(_testAddress);

      expect(repository.lastRequest!.idempotencyKey, isNotNull);
      expect(repository.lastRequest!.idempotencyKey, isNotEmpty);
    },
  );
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

/// A [FoodOrderRepository] fake that records every request it receives and
/// resolves immediately with an incrementing order id.
class _RecordingFoodOrderRepository implements FoodOrderRepository {
  int callCount = 0;
  FoodOrderRequest? lastRequest;

  @override
  Future<String> placeOrder(FoodOrderRequest request) async {
    callCount++;
    lastRequest = request;
    return 'food-order-$callCount';
  }
}

/// A [FoodOrderRepository] fake whose [placeOrder] only resolves once the
/// test calls [complete], so a test can observe controller state (e.g.
/// [FoodController.isSubmitting]) while a submission is still in flight.
class _ControllableFoodOrderRepository implements FoodOrderRepository {
  int callCount = 0;
  final _pending = Completer<String>();

  void complete(String orderId) => _pending.complete(orderId);

  @override
  Future<String> placeOrder(FoodOrderRequest request) {
    callCount++;
    return _pending.future;
  }
}
