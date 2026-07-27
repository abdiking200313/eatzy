import 'package:chowflow/config/theme.dart';
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/features/super_app/presentation/super_app_home_screen.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('super-app home exposes every service and Somalia locale', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SuperAppHomeScreen()),
        for (final path in const [
          '/food',
          '/grocery',
          '/pharmacy',
          '/cleaning',
        ])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.uri.path)),
          ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('What do you need today?'), findsNothing);
    expect(find.text('Somalia • USD'), findsNothing);
    for (final label in ['Food', 'Grocery', 'Pharmacy', 'Cleaning']) {
      expect(find.text(label), findsOneWidget);
    }
    final groceryCard = tester.widget<Material>(
      find.byKey(const Key('service-grocery')),
    );
    expect(groceryCard.color, ServiceThemes.grocery.card);
    expect(
      tester.getTopLeft(find.text('Good morning')).dy,
      lessThan(tester.getTopLeft(find.text('Food')).dy),
    );

    await tester.tap(find.byKey(const Key('service-grocery')));
    await tester.pumpAndSettle();
    expect(find.text('/grocery'), findsOneWidget);
  });

  testWidgets('service grid stays overflow-free on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: SuperAppHomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Good morning'), findsOneWidget);
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
          amount: 24,
          detailsRoute: '/grocery',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SuperAppHomeScreen(activityController: controller),
      ),
    );

    expect(find.text('Recent Activity'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();
    expect(find.text('Bakaara groceries'), findsOneWidget);
    expect(find.text(r'$24.00'), findsOneWidget);
  });
}
