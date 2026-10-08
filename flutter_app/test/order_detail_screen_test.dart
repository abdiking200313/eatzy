import 'package:chowflow/features/merchant/orders/models/merchant_order.dart';
import 'package:chowflow/features/merchant/orders/presentation/merchant_orders_controller.dart';
import 'package:chowflow/features/merchant/orders/presentation/order_detail_screen.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

/// Widget-tests `OrderDetailScreen` directly (rather than only through
/// `OrdersScreen`'s navigation), covering the rest of a vertical's status
/// vocabulary and the terminal state (ported from `merchant_app`,
/// originally issue #134's "advance status through the rest of that
/// vertical's vocabulary ... no direct table writes", unified into the main
/// app by issue #232).
void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  MerchantOrder orderWithStatus(String status) => MerchantOrder.fromMap({
    'id': 'order-1',
    'status': status,
    'created_at': '2026-09-01T12:00:00Z',
    'subtotal': 500,
    'delivery_fee': 499,
    'tax': 50,
    'total': 1049,
    'recipient_name': 'Amina',
    'phone': '+252-61-000-0000',
    'street': 'Main St',
    'district': 'Hodan',
    'city': 'Mogadishu',
    'food_order_items': [
      {'id': 1, 'item_name': 'Sambusa', 'quantity': 2, 'unit_price': 250},
    ],
  }, vertical: MerchantVertical.food);

  testWidgets('a confirmed order offers accept and reject', (tester) async {
    final order = orderWithStatus('confirmed');
    final controller = MerchantOrdersController(
      repository: FakeMerchantOrdersRepository(initialOrders: [order]),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );
    await controller.load();

    await tester.pumpWidget(
      wrap(OrderDetailScreen(controller: controller, orderId: order.id)),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Accept order'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reject order'), findsOneWidget);
  });

  testWidgets('rejecting a confirmed order cancels it', (tester) async {
    final order = orderWithStatus('confirmed');
    final controller = MerchantOrdersController(
      repository: FakeMerchantOrdersRepository(initialOrders: [order]),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );
    await controller.load();

    await tester.pumpWidget(
      wrap(OrderDetailScreen(controller: controller, orderId: order.id)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject order'));
    await tester.pumpAndSettle();

    expect(controller.orders.single.status, 'cancelled');
    expect(find.text('Cancelled'), findsWidgets);
    // A cancelled order is terminal -- no further actions offered.
    expect(find.widgetWithText(FilledButton, 'Accept order'), findsNothing);
  });

  testWidgets(
    'a preparing order offers "mark as out for delivery" and cancel',
    (tester) async {
      final order = orderWithStatus('preparing');
      final controller = MerchantOrdersController(
        repository: FakeMerchantOrdersRepository(initialOrders: [order]),
        vertical: MerchantVertical.food,
        storeId: 'store-1',
      );
      await controller.load();

      await tester.pumpWidget(
        wrap(OrderDetailScreen(controller: controller, orderId: order.id)),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Mark as Out for delivery'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Cancel order'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Mark as Out for delivery'),
      );
      await tester.pumpAndSettle();

      expect(controller.orders.single.status, 'out_for_delivery');
    },
  );

  testWidgets('out for delivery can only be marked delivered, not cancelled', (
    tester,
  ) async {
    final order = orderWithStatus('out_for_delivery');
    final controller = MerchantOrdersController(
      repository: FakeMerchantOrdersRepository(initialOrders: [order]),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );
    await controller.load();

    await tester.pumpWidget(
      wrap(OrderDetailScreen(controller: controller, orderId: order.id)),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Mark as Delivered'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Cancel order'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Mark as Delivered'));
    await tester.pumpAndSettle();

    expect(controller.orders.single.status, 'delivered');
  });

  testWidgets('a delivered order offers no further actions', (tester) async {
    final order = orderWithStatus('delivered');
    final controller = MerchantOrdersController(
      repository: FakeMerchantOrdersRepository(initialOrders: [order]),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );
    await controller.load();

    await tester.pumpWidget(
      wrap(OrderDetailScreen(controller: controller, orderId: order.id)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This order is complete. No further action is available.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('shows a fallback when the order is no longer available', (
    tester,
  ) async {
    final controller = MerchantOrdersController(
      repository: FakeMerchantOrdersRepository(),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );
    await controller.load();

    await tester.pumpWidget(
      wrap(OrderDetailScreen(controller: controller, orderId: 'missing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('This order is no longer available.'), findsOneWidget);
  });
}
