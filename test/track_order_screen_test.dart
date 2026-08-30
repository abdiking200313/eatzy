import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/orders/presentation/track_order_screen.dart';
import 'package:chowflow/platform/activity/data/activity_repository.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackOrderScreen (issue #43)', () {
    testWidgets('renders the real fetched order instead of fake data', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: TrackOrderScreen(
            orderId: 'order-1',
            serviceId: 'food',
            repository: _FakeOrderDetailsRepository(
              ActivityItem(
                id: 'order-1',
                serviceId: ServiceId.food,
                title: 'Jollof Feast Order',
                status: 'On the way',
                occurredAt: DateTime.utc(2026, 8, 1),
                amount: 18.5,
                detailsRoute: '/food',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jollof Feast Order'), findsOneWidget);
      expect(find.text('Order #order-1'), findsOneWidget);
      expect(find.text('On the way'), findsWidgets);

      // No fabricated courier or ETA anywhere on screen (see issue #43).
      expect(find.textContaining('minutes'), findsNothing);
      expect(find.byIcon(Icons.call), findsNothing);
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
      await tester.pumpWidget(
        MaterialApp(
          home: TrackOrderScreen(
            orderId: 'missing-order',
            serviceId: 'food',
            repository: const _NotFoundOrderDetailsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order not found'), findsOneWidget);
    });

    testWidgets('shows a retry action when the lookup fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackOrderScreen(
            orderId: 'order-1',
            serviceId: 'food',
            repository: const _FailingOrderDetailsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order could not be loaded'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

class _FakeOrderDetailsRepository implements OrderDetailsRepository {
  const _FakeOrderDetailsRepository(this.order);

  final ActivityItem order;

  @override
  Future<ActivityItem?> fetchOrderById({
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
}

class _FailingOrderDetailsRepository implements OrderDetailsRepository {
  const _FailingOrderDetailsRepository();

  @override
  Future<ActivityItem?> fetchOrderById({
    required String orderId,
    required String serviceId,
  }) async => throw StateError('boom: order lookup failed');
}
