import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/orders/presentation/track_order_screen.dart';
import 'package:chowflow/platform/activity/data/activity_repository.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/models/order_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityItem _summary({
  String status = 'preparing',
  ServiceId serviceId = ServiceId.food,
  String? paymentMethod,
  String? paymentStatus,
}) => ActivityItem(
  id: '3f2a9c1e-0000-4000-8000-000000000001',
  serviceId: serviceId,
  title: 'Jollof Feast Order',
  status: status,
  occurredAt: DateTime.utc(2026, 8, 1, 12),
  amount: 2950,
  detailsRoute: '/food',
  paymentMethod: paymentMethod,
  paymentStatus: paymentStatus,
);

OrderDetails _details(
  ActivityItem summary, {
  String? street = 'Maka Al Mukarama',
}) => OrderDetails(
  summary: summary,
  storeName: 'Jollof Feast',
  lines: const [
    OrderLine(name: 'Jollof Rice', quantity: 2, unitPrice: 1000),
    OrderLine(name: 'Plantain', quantity: 1, unitPrice: 450),
  ],
  subtotal: 2450,
  deliveryFee: 300,
  tax: 200,
  total: 2950,
  recipientName: 'Amina',
  phone: '+252 61 000 0000',
  street: street,
  district: 'Hodan',
  city: 'Mogadishu',
);

Future<void> _pump(
  WidgetTester tester,
  OrderDetailsRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: TrackOrderScreen(
        orderId: '3f2a9c1e-0000-4000-8000-000000000001',
        serviceId: 'food',
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TrackOrderScreen order details', () {
    testWidgets('shows the order, its items, charges, address and a real '
        'progress timeline', (tester) async {
      await _pump(tester, _FakeOrderDetailsRepository(_details(_summary())));

      expect(find.text('Order details'), findsOneWidget);
      expect(find.text('Jollof Feast'), findsOneWidget);
      expect(find.text('Order #3F2A9C1E'), findsOneWidget);

      // Timeline: every step of the food flow, current one included.
      expect(find.text('Track order'), findsOneWidget);
      for (final step in ['Confirmed', 'Out for delivery', 'Delivered']) {
        expect(find.text(step), findsOneWidget);
      }
      // "Preparing" is both the status pill and the current step.
      expect(find.text('Preparing'), findsNWidgets(2));

      expect(find.text('2x'), findsOneWidget);
      expect(find.text('Jollof Rice'), findsOneWidget);
      expect(find.text('Plantain'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Delivery fee'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Delivery address'), 200);
      expect(find.text('Maka Al Mukarama, Hodan, Mogadishu'), findsOneWidget);

      // No fabricated courier or ETA anywhere on screen (see issue #43).
      expect(find.textContaining('minutes'), findsNothing);
      expect(find.byIcon(Icons.call), findsNothing);

      // No payment card when the order has no payment fields.
      expect(find.text('Payment'), findsNothing);

      await tester.scrollUntilVisible(find.text('Order again'), 200);
      expect(find.text('Order again'), findsOneWidget);
    });

    testWidgets('a cancelled order shows a cancelled step, not the flow', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeOrderDetailsRepository(_details(_summary(status: 'cancelled'))),
      );

      expect(find.text('Order cancelled'), findsOneWidget);
      expect(find.text('Out for delivery'), findsNothing);
    });

    testWidgets('grocery kilogram lines show their weight', (tester) async {
      await _pump(
        tester,
        _FakeOrderDetailsRepository(
          OrderDetails(
            summary: _summary(serviceId: ServiceId.grocery, status: 'shopping'),
            lines: const [
              OrderLine(
                name: 'Tomatoes',
                quantity: 1.5,
                unitPrice: 200,
                pricingUnit: 'kilogram',
              ),
            ],
            subtotal: 300,
            deliveryFee: 0,
            total: 300,
          ),
        ),
      );

      expect(find.text('1.5 kg'), findsOneWidget);
      expect(find.text('Shopping'), findsNWidgets(2));
      // No address stored: no empty address card.
      expect(find.text('Delivery address'), findsNothing);
    });

    testWidgets('shows the order\'s real payment method and status (issue '
        '#30)', (tester) async {
      await _pump(
        tester,
        _FakeOrderDetailsRepository(
          _details(
            _summary(
              paymentMethod: 'cash_on_delivery',
              paymentStatus: 'pending_collection',
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(find.text('Payment'), 200);
      expect(find.text('Cash on delivery'), findsOneWidget);
      expect(find.text('Pending collection'), findsOneWidget);
    });

    testWidgets('an unknown-service order has no "Order again"', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeOrderDetailsRepository(
          _details(_summary(serviceId: ServiceId.unknown)),
        ),
      );

      expect(find.text('Order again'), findsNothing);
    });

    testWidgets(
      'shows a "no order selected" empty state for the bare route, without '
      'crashing',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: TrackOrderScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('No order selected'), findsOneWidget);
      },
    );

    testWidgets('shows a not-found state when the order does not resolve', (
      tester,
    ) async {
      await _pump(tester, const _NotFoundOrderDetailsRepository());

      expect(tester.takeException(), isNull);
      expect(find.text('Order not found'), findsOneWidget);
    });

    testWidgets('shows a retry action when the lookup fails', (tester) async {
      await _pump(tester, const _FailingOrderDetailsRepository());

      expect(find.text('Order could not be loaded'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
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

class _NotFoundOrderDetailsRepository implements OrderDetailsRepository {
  const _NotFoundOrderDetailsRepository();

  @override
  Future<ActivityItem?> fetchOrderById({
    required String orderId,
    required String serviceId,
  }) async => null;

  @override
  Future<OrderDetails?> fetchOrderDetails({
    required String orderId,
    required String serviceId,
  }) async => null;
}

class _FailingOrderDetailsRepository implements OrderDetailsRepository {
  const _FailingOrderDetailsRepository();

  @override
  Future<ActivityItem?> fetchOrderById({
    required String orderId,
    required String serviceId,
  }) async => throw StateError('boom: order lookup failed');

  @override
  Future<OrderDetails?> fetchOrderDetails({
    required String orderId,
    required String serviceId,
  }) async => throw StateError('boom: order lookup failed');
}
