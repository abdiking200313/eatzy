import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/orders/data/merchant_orders_repository.dart';
import 'package:merchant_app/features/orders/models/merchant_order.dart';
import 'package:merchant_app/features/orders/presentation/merchant_orders_controller.dart';
import 'package:merchant_app/features/store/models/merchant_vertical.dart';

import 'fakes/fake_merchant_repositories.dart';

// Unit-tests `MerchantOrdersController`'s load/advance-status bookkeeping
// (issue #134) against the fake repository, including the "illegal
// transition surfaces a clear error, not a silent no-op" acceptance
// criterion.
void main() {
  final confirmedOrder = MerchantOrder.fromMap({
    'id': 'order-1',
    'status': 'confirmed',
    'created_at': '2026-09-01T12:00:00Z',
    'subtotal': 1000,
    'delivery_fee': 499,
    'tax': 100,
    'total': 1599,
    'recipient_name': 'Amina',
    'phone': '+252-61-000-0000',
    'street': 'Main St',
    'district': 'Hodan',
    'city': 'Mogadishu',
    'food_order_items': [
      {'id': 1, 'item_name': 'Sambusa', 'quantity': 2, 'unit_price': 250},
    ],
  }, vertical: MerchantVertical.food);

  group('load', () {
    test('populates orders and hasLoaded on success', () async {
      final controller = MerchantOrdersController(
        repository: FakeMerchantOrdersRepository(
          initialOrders: [confirmedOrder],
        ),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      expect(controller.hasLoaded, isFalse);
      await controller.load();

      expect(controller.hasLoaded, isTrue);
      expect(controller.orders, [confirmedOrder]);
      expect(controller.loadError, isNull);
    });

    test('hasLoaded is true with no orders yet', () async {
      final controller = MerchantOrdersController(
        repository: FakeMerchantOrdersRepository(),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      await controller.load();

      expect(controller.hasLoaded, isTrue);
      expect(controller.orders, isEmpty);
    });

    test('sets loadError on failure', () async {
      final repository = FakeMerchantOrdersRepository()
        ..failureToThrow = Exception('network down');
      final controller = MerchantOrdersController(
        repository: repository,
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );

      await controller.load();

      expect(controller.loadError, isNotNull);
      expect(controller.orders, isEmpty);
    });
  });

  group('advanceStatus', () {
    test('accepting a confirmed order advances it to preparing', () async {
      final controller = MerchantOrdersController(
        repository: FakeMerchantOrdersRepository(
          initialOrders: [confirmedOrder],
        ),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );
      await controller.load();

      final succeeded = await controller.advanceStatus(
        confirmedOrder,
        'preparing',
      );

      expect(succeeded, isTrue);
      expect(controller.orders.single.status, 'preparing');
      expect(controller.saveError, isNull);
    });

    test('rejecting a confirmed order cancels it', () async {
      final controller = MerchantOrdersController(
        repository: FakeMerchantOrdersRepository(
          initialOrders: [confirmedOrder],
        ),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );
      await controller.load();

      final succeeded = await controller.advanceStatus(
        confirmedOrder,
        'cancelled',
      );

      expect(succeeded, isTrue);
      expect(controller.orders.single.status, 'cancelled');
    });

    test(
      'an illegal transition fails with a clear error, not a silent no-op',
      () async {
        final controller = MerchantOrdersController(
          repository: FakeMerchantOrdersRepository(
            initialOrders: [confirmedOrder],
          ),
          vertical: MerchantVertical.food,
          storeId: 'store-1',
        );
        await controller.load();

        // confirmed -> out_for_delivery skips the required "preparing" step.
        final succeeded = await controller.advanceStatus(
          confirmedOrder,
          'out_for_delivery',
        );

        expect(succeeded, isFalse);
        expect(controller.saveError, isNotNull);
        expect(
          controller.saveError,
          contains('Illegal food order status transition'),
        );
        // The order's status must not have changed on a rejected transition.
        expect(controller.orders.single.status, 'confirmed');
      },
    );

    test('surfaces a generic message for a non-transition error', () async {
      final repository = FakeMerchantOrdersRepository(
        initialOrders: [confirmedOrder],
      );
      final controller = MerchantOrdersController(
        repository: repository,
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );
      await controller.load();
      repository.failureToThrow = Exception('network down');

      final succeeded = await controller.advanceStatus(
        confirmedOrder,
        'preparing',
      );

      expect(succeeded, isFalse);
      expect(
        controller.saveError,
        'The order status could not be updated. Please try again.',
      );
    });
  });

  group('orderById', () {
    test('returns null once loaded orders no longer contain the id', () async {
      final controller = MerchantOrdersController(
        repository: FakeMerchantOrdersRepository(),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );
      await controller.load();

      expect(controller.orderById('missing'), isNull);
    });
  });

  test('OrderStatusTransitionException.toString returns the raw message', () {
    const error = OrderStatusTransitionException('boom');
    expect(error.toString(), 'boom');
  });
}
