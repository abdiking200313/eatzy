import 'package:chowflow/config/theme.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/features/super_app/presentation/super_app_home_screen.dart';
import 'package:chowflow/services/food/models/restaurant.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/widgets/app_misc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<List<Restaurant>> _noRestaurants() async => const <Restaurant>[];

void main() {
  testWidgets('super-app home exposes every service and Somalia locale', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const SuperAppHomeScreen(restaurantLoader: _noRestaurants),
        ),
        for (final path in const ['/food', '/grocery', '/pharmacy'])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.uri.path)),
          ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    // Issue #143: the header greeting was removed entirely.
    expect(find.text('Good morning'), findsNothing);
    expect(find.text('What do you need today?'), findsNothing);
    expect(find.text('Somalia • USD'), findsNothing);
    for (final label in ['Food', 'Grocery', 'Pharmacy']) {
      expect(find.text(label), findsOneWidget);
    }
    final groceryCard = tester.widget<Material>(
      find.byKey(const Key('service-grocery')),
    );
    // White cards only: the service accent stays confined to the 48px icon
    // chip, so the card fill itself is the neutral token, never the
    // per-service tinted `ServiceThemes.grocery.card`.
    expect(groceryCard.color, TwColors.card);
    expect(
      find.descendant(
        of: find.byKey(const Key('service-grocery')),
        matching: find.byType(ServiceIconChip),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Search restaurants, stores...')).dy,
      lessThan(tester.getTopLeft(find.text('Food')).dy),
    );

    await tester.tap(find.byKey(const Key('service-grocery')));
    await tester.pumpAndSettle();
    expect(find.text('/grocery'), findsOneWidget);
  });

  testWidgets('category grid is 4 columns: services, coming soon, then More', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const SuperAppHomeScreen(restaurantLoader: _noRestaurants),
      ),
    );
    await tester.pump();

    const keys = [
      'service-grocery',
      'service-food',
      'service-pharmacy',
      'coming-soon-fresh-meat',
      'coming-soon-delivery',
      'coming-soon-deals',
      'coming-soon-electronics',
      'service-more',
    ];
    final tops = [
      for (final key in keys) tester.getTopLeft(find.byKey(Key(key))),
    ];
    // Row one is the first four tiles, row two the last four, left to right.
    for (var i = 0; i < 4; i++) {
      expect(tops[i].dy, tops[0].dy);
      expect(tops[i + 4].dy, tops[4].dy);
      expect(tops[i + 4].dx, tops[i].dx);
    }
    expect(tops[4].dy, greaterThan(tops[0].dy));
    expect(tops[1].dx, greaterThan(tops[0].dx));

    for (final label in [
      'Fresh Meat',
      'Delivery',
      'Deals',
      'Electronics',
      'More',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Only the four placeholders carry the badge.
    expect(find.text('Soon'), findsNWidgets(4));
  });

  testWidgets('coming-soon tile shows a snackbar instead of navigating', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const SuperAppHomeScreen(restaurantLoader: _noRestaurants),
        ),
        GoRoute(
          path: '/services',
          builder: (_, _) => const Scaffold(body: Text('services screen')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('coming-soon-deals')));
    await tester.pump();
    expect(find.text('Deals is coming soon'), findsOneWidget);
    expect(find.text('services screen'), findsNothing);

    // "More" is a real link to the full list, not a placeholder.
    await tester.tap(find.byKey(const Key('service-more')));
    await tester.pumpAndSettle();
    expect(find.text('services screen'), findsOneWidget);
  });

  testWidgets('service grid stays overflow-free on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: const SuperAppHomeScreen(restaurantLoader: _noRestaurants),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Good morning'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home previews recent cross-service activity', (tester) async {
    final controller = ActivityController()
      ..record(
        ActivityItem(
          id: 'grocery-preview',
          serviceId: ServiceId.grocery,
          title: 'Bakaara groceries',
          status: 'Confirmed',
          occurredAt: DateTime(2026, 7, 27),
          amount: 2400,
          detailsRoute: '/grocery',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SuperAppHomeScreen(
          activityController: controller,
          restaurantLoader: _noRestaurants,
        ),
      ),
    );

    for (
      var attempt = 0;
      attempt < 8 && find.text('Bakaara groceries').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
    }
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Bakaara groceries'), findsOneWidget);
    expect(find.text(r'$24.00'), findsOneWidget);
    // Status pills instead of bare colored status text.
    expect(find.widgetWithText(StatusPill, 'Confirmed'), findsOneWidget);
  });

  testWidgets(
    'Recent Activity preview is one list card with row dividers, not one '
    'card per row',
    (tester) async {
      final controller = ActivityController()
        ..record(
          ActivityItem(
            id: 'grocery-preview',
            serviceId: ServiceId.grocery,
            title: 'Bakaara groceries',
            status: 'Confirmed',
            occurredAt: DateTime(2026, 7, 27),
            amount: 24,
            detailsRoute: '/grocery',
          ),
        )
        ..record(
          ActivityItem(
            id: 'food-preview',
            serviceId: ServiceId.food,
            title: 'Lunch order',
            status: 'Delivered',
            occurredAt: DateTime(2026, 7, 28),
            amount: 12,
            detailsRoute: '/food',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SuperAppHomeScreen(
            activityController: controller,
            restaurantLoader: _noRestaurants,
          ),
        ),
      );

      for (
        var attempt = 0;
        attempt < 8 && find.text('Lunch order').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
      }
      expect(find.text('Bakaara groceries'), findsOneWidget);
      expect(find.text('Lunch order'), findsOneWidget);

      // One card holds every recent-activity row — this would regress to
      // 2 (one per row) if the list ever went back to a per-item bordered
      // card, per the "one card per list, not one card per row" rule.
      expect(find.byType(Card), findsOneWidget);
      // A divider separates the two rows inside that single card.
      expect(
        find.descendant(of: find.byType(Card), matching: find.byType(Divider)),
        findsOneWidget,
      );
    },
  );
}
