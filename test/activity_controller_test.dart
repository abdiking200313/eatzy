import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/data/activity_repository.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/activity/presentation/activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('activity controller keeps newest records first and replaces IDs', () {
    final controller = ActivityController();
    final older = DateTime(2026, 7, 1);
    final newer = DateTime(2026, 7, 2);

    controller.record(
      ActivityItem(
        id: 'same',
        serviceId: ServiceId.food,
        title: 'Food order',
        status: 'Confirmed',
        occurredAt: older,
        amount: 10,
        detailsRoute: '/food',
      ),
    );
    controller.record(
      ActivityItem(
        id: 'grocery',
        serviceId: ServiceId.grocery,
        title: 'Grocery order',
        status: 'Confirmed',
        occurredAt: newer,
        amount: 20,
        detailsRoute: '/grocery',
      ),
    );
    controller.record(
      ActivityItem(
        id: 'same',
        serviceId: ServiceId.food,
        title: 'Updated food order',
        status: 'Ready',
        occurredAt: newer.add(const Duration(hours: 1)),
        amount: 12,
        detailsRoute: '/food',
      ),
    );

    expect(controller.items.map((item) => item.id), ['same', 'grocery']);
    expect(controller.items.first.status, 'Ready');
  });

  testWidgets('activity screen renders unified service records', (
    tester,
  ) async {
    final controller = ActivityController()
      ..record(
        ActivityItem(
          id: 'pharmacy-1',
          serviceId: ServiceId.pharmacy,
          title: 'Pharmacy order',
          status: 'MVP confirmed',
          occurredAt: DateTime.utc(2026, 7, 27),
          amount: 54,
          detailsRoute: '',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ActivityScreen(controller: controller)),
    );

    expect(find.text('Pharmacy order'), findsOneWidget);
    expect(find.text(r'$54.00'), findsOneWidget);
    expect(find.text('MVP confirmed'), findsOneWidget);
  });

  test(
    'ActivityItem.fromMap drops a legacy cleaning row instead of throwing',
    () {
      final item = ActivityItem.fromMap({
        'id': 'legacy-cleaning-1',
        'service_id': 'cleaning',
        'title': 'Deep clean',
        'status': 'completed',
        'occurred_at': DateTime.utc(2026, 7, 27).toIso8601String(),
        'amount': 54,
        'details_route': '/cleaning',
      });

      expect(item, isNull);
    },
  );

  test('ActivityItem.fromMap falls back to ServiceId.unknown for a genuinely '
      'unsupported service instead of throwing', () {
    final item = ActivityItem.fromMap({
      'id': 'unknown-1',
      'service_id': 'not-a-real-service',
      'title': 'Mystery order',
      'status': 'completed',
      'occurred_at': DateTime.utc(2026, 7, 27).toIso8601String(),
      'amount': 10,
      'details_route': '/unknown',
    });

    expect(item, isNotNull);
    expect(item!.serviceId, ServiceId.unknown);
    expect(item.title, 'Mystery order');
  });

  test('ActivityItem.fromMap still throws for other malformed fields (missing '
      'title), which ActivityRepository catches per row', () {
    expect(
      () => ActivityItem.fromMap({
        'id': 'bad-title-1',
        'service_id': 'food',
        'title': '',
        'status': 'completed',
        'occurred_at': DateTime.utc(2026, 7, 27).toIso8601String(),
        'amount': 10,
        'details_route': '/food',
      }),
      throwsFormatException,
    );
  });

  testWidgets('pulling to refresh reloads activity from the repository', (
    tester,
  ) async {
    final repository = _CountingActivityRepository();
    final controller = ActivityController(repository: repository);
    await controller.load();
    expect(repository.fetchCount, 1);

    await tester.pumpWidget(
      MaterialApp(home: ActivityScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
  });

  group('"Track order" row action (issue #43)', () {
    testWidgets('a real-service row exposes a track action that navigates to '
        'trackOrderDetails with that row\'s service/order id', (tester) async {
      final controller = ActivityController()
        ..record(
          ActivityItem(
            id: 'food-1',
            serviceId: ServiceId.food,
            title: 'Jollof Feast Order',
            status: 'On the way',
            occurredAt: DateTime.utc(2026, 8, 1),
            amount: 18.5,
            detailsRoute: '/food',
          ),
        );

      String? capturedServiceId;
      String? capturedOrderId;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ActivityScreen(controller: controller),
          ),
          GoRoute(
            path: AppRoutes.trackOrderDetails,
            builder: (_, state) {
              capturedServiceId = state.pathParameters['serviceId'];
              capturedOrderId = state.pathParameters['orderId'];
              return const Scaffold(body: Text('track order screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // The existing row tap (issue #67, navigates to the shell home)
      // must remain intact -- this is an ADDITION, not a replacement.
      expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.local_shipping_outlined));
      await tester.pumpAndSettle();

      expect(find.text('track order screen'), findsOneWidget);
      expect(capturedServiceId, 'food');
      expect(capturedOrderId, 'food-1');
    });

    testWidgets(
      'a row with an unrecognized service has no track action (there is no '
      'real service_id left to key a lookup on, see #62)',
      (tester) async {
        final controller = ActivityController()
          ..record(
            ActivityItem(
              id: 'unknown-1',
              serviceId: ServiceId.unknown,
              title: 'Mystery order',
              status: 'completed',
              occurredAt: DateTime.utc(2026, 7, 27),
              amount: 10,
              detailsRoute: '',
            ),
          );

        await tester.pumpWidget(
          MaterialApp(home: ActivityScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
      },
    );
  });
}

class _CountingActivityRepository implements ActivityRepository {
  int fetchCount = 0;

  @override
  Future<List<ActivityItem>> fetchActivities({int limit = 100}) async {
    fetchCount++;
    return const [];
  }
}
