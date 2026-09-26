import 'package:cached_network_image/cached_network_image.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/features/super_app/presentation/super_app_home_screen.dart';
import 'package:chowflow/platform/discovery/store_listing.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/widgets/app_misc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<List<StoreListing>> _noStores() async => const <StoreListing>[];

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
              const SuperAppHomeScreen(storeListingLoader: _noStores),
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
    // The tile is a full-bleed photo on a neutral backing, never tinted with
    // the per-service color.
    expect(groceryCard.color, TwColors.stone100);
    expect(
      find.descendant(
        of: find.byKey(const Key('service-grocery')),
        matching: find.byType(CachedNetworkImage),
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

  testWidgets(
    'category grid is 3 columns of services then More, with no coming-soon placeholders',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const SuperAppHomeScreen(storeListingLoader: _noStores),
        ),
      );
      await tester.pump();

      const keys = [
        'service-grocery',
        'service-food',
        'service-pharmacy',
        'service-fresh-meat',
        'service-electronics',
        'service-more',
      ];
      final tops = [
        for (final key in keys) tester.getTopLeft(find.byKey(Key(key))),
      ];
      // Row one is the first three tiles, row two the last three, left to
      // right.
      for (var i = 0; i < 3; i++) {
        expect(tops[i].dy, tops[0].dy);
        expect(tops[i + 3].dy, tops[3].dy);
        expect(tops[i + 3].dx, tops[i].dx);
      }
      expect(tops[3].dy, greaterThan(tops[0].dy));
      expect(tops[1].dx, greaterThan(tops[0].dx));

      for (final label in ['Fresh Meat', 'Electronics', 'More']) {
        expect(find.text(label), findsOneWidget);
      }
      // Coming-soon categories live only on the full Services list.
      for (final label in ['Delivery', 'Deals', 'Soon']) {
        expect(find.text(label), findsNothing);
      }
    },
  );

  testWidgets('"More" opens the full Services list', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const SuperAppHomeScreen(storeListingLoader: _noStores),
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

    await tester.ensureVisible(find.byKey(const Key('service-more')));
    await tester.pump();
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
          child: const SuperAppHomeScreen(storeListingLoader: _noStores),
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
          storeListingLoader: _noStores,
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
            storeListingLoader: _noStores,
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
