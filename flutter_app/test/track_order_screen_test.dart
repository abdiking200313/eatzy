import 'dart:async';

import 'package:chowflow/app/app_scope.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/orders/presentation/track_order_screen.dart';
import 'package:chowflow/platform/activity/data/activity_repository.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/models/order_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_scope_test_helpers.dart';

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
  // TrackOrderScreen always builds its own default OrderAgainService (no
  // test here injects one), which now resolves its Supabase client from
  // AppScope (issue #284) rather than `Supabase.instance.client` -- so every
  // pump needs an AppScope ancestor even though `repository` above is
  // injected directly.
  await tester.pumpWidget(
    AppScope(
      services: buildTestAppServices(),
      child: MaterialApp(
        theme: buildAppTheme(),
        home: TrackOrderScreen(
          orderId: '3f2a9c1e-0000-4000-8000-000000000001',
          serviceId: 'food',
          repository: repository,
        ),
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
        await tester.pumpWidget(
          AppScope(
            services: buildTestAppServices(),
            child: const MaterialApp(home: TrackOrderScreen()),
          ),
        );
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

  group('TrackOrderScreen live updates (issue #297)', () {
    testWidgets(
      'a watchOrder tick triggers a refetch and the UI reflects the new '
      'status',
      (tester) async {
        final repository = _FakeOrderDetailsRepository(
          _details(_summary(status: 'preparing')),
        );
        await _pump(tester, repository);

        expect(find.text('Preparing'), findsNWidgets(2));
        expect(repository.watchOrderCallCount, 1);

        // Simulate the merchant moving the order forward server-side, then
        // a realtime event firing for it.
        repository.order = _details(_summary(status: 'out_for_delivery'));
        repository.emitOrderChanged();
        await tester.pumpAndSettle();

        expect(find.text('Out for delivery'), findsNWidgets(2));
        // The status pill no longer reads "Preparing", but the timeline
        // still shows it as a completed step -- see `TrackingCard`.
        expect(find.text('Preparing'), findsOneWidget);
        // Still just the one subscription -- ticks reuse it rather than
        // resubscribing.
        expect(repository.watchOrderCallCount, 1);
      },
    );

    testWidgets('the subscription is cancelled when the screen is disposed', (
      tester,
    ) async {
      final repository = _FakeOrderDetailsRepository(_details(_summary()));
      await _pump(tester, repository);

      expect(repository.watchOrderCallCount, 1);
      expect(repository.watchCancelled, isFalse);

      // Replace the whole tree so `TrackOrderScreen`'s State is disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(repository.watchCancelled, isTrue);
    });

    testWidgets('does not subscribe for an order already in a final state', (
      tester,
    ) async {
      final delivered = _FakeOrderDetailsRepository(
        _details(_summary(status: 'delivered')),
      );
      await _pump(tester, delivered);
      expect(delivered.watchOrderCallCount, 0);

      final cancelled = _FakeOrderDetailsRepository(
        _details(_summary(status: 'cancelled')),
      );
      await _pump(tester, cancelled);
      expect(cancelled.watchOrderCallCount, 0);
    });
  });
}

class _FakeOrderDetailsRepository implements OrderDetailsRepository {
  _FakeOrderDetailsRepository(this.order);

  /// Mutable so a test can change the order returned by the *next*
  /// [fetchOrderDetails] call, then push a [watchOrder] tick to simulate a
  /// merchant-driven status change landing between refetches.
  OrderDetails order;

  /// How many times [watchOrder] has been called -- a test asserts this
  /// stays `0` for an order that's already in a final state (issue #297).
  int watchOrderCallCount = 0;

  /// Set from the stream controller's `onCancel`, i.e. once nothing is
  /// listening anymore -- `TrackOrderScreen.dispose` should cause this.
  bool watchCancelled = false;

  StreamController<void>? _watchController;

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

  @override
  Stream<void> watchOrder({
    required String orderId,
    required String serviceId,
  }) {
    watchOrderCallCount++;
    final controller = StreamController<void>.broadcast(
      onCancel: () => watchCancelled = true,
    );
    _watchController = controller;
    return controller.stream;
  }

  /// Simulates a realtime `postgres_changes` event firing.
  void emitOrderChanged() => _watchController?.add(null);
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

  @override
  Stream<void> watchOrder({
    required String orderId,
    required String serviceId,
  }) => const Stream<void>.empty();
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

  @override
  Stream<void> watchOrder({
    required String orderId,
    required String serviceId,
  }) => const Stream<void>.empty();
}
