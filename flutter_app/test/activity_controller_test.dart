import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/data/activity_repository.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/activity/presentation/activity_screen.dart';
import 'package:chowflow/platform/error_reporting/error_reporter.dart';
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
          amount: 5400,
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

  test('load() reports the original exception and stack trace through '
      'ErrorReporting instead of discarding them, while still setting the '
      'generic user-facing error (issues #19, #286)', () async {
    final error = StateError('boom: repository unreachable');
    final repository = _FailingActivityRepository(error);
    final controller = ActivityController(repository: repository);

    final originalReporter = ErrorReporting.instance;
    final fakeReporter = _FakeErrorReporter();
    ErrorReporting.instance = fakeReporter;
    try {
      await controller.load();
    } finally {
      ErrorReporting.instance = originalReporter;
    }

    expect(
      controller.loadError,
      'Activity could not be loaded. Please try again.',
    );
    expect(fakeReporter.reported, hasLength(1));
    expect(fakeReporter.reported.single.error, error);
    expect(fakeReporter.reported.single.context, 'ActivityController.load');
  });

  group('tapping an order row opens its order details', () {
    testWidgets('a real-service row navigates to '
        'trackOrderDetails with that row\'s service/order id', (tester) async {
      final controller = ActivityController()
        ..record(
          ActivityItem(
            id: 'food-1',
            serviceId: ServiceId.food,
            title: 'Jollof Feast Order',
            status: 'On the way',
            occurredAt: DateTime.utc(2026, 8, 1),
            amount: 1850,
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

      // No separate truck icon or "Order again" on the row any more: both
      // live on the order details page.
      expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
      expect(find.text('Order again'), findsNothing);

      await tester.tap(find.text('Jollof Feast Order'));
      await tester.pumpAndSettle();

      expect(find.text('track order screen'), findsOneWidget);
      expect(capturedServiceId, 'food');
      expect(capturedOrderId, 'food-1');
    });

    testWidgets(
      'a row with an unrecognized service does not navigate (there is no '
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

        await tester.tap(find.text('Mystery order'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Mystery order'), findsOneWidget);
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

class _FailingActivityRepository implements ActivityRepository {
  _FailingActivityRepository(this.error);

  final Object error;

  @override
  Future<List<ActivityItem>> fetchActivities({int limit = 100}) async {
    throw error;
  }
}

class _FakeErrorReporter implements ErrorReporter {
  final List<({Object error, StackTrace stack, String? context})> reported = [];

  @override
  void reportError(Object error, StackTrace stack, {String? context}) {
    reported.add((error: error, stack: stack, context: context));
  }
}
