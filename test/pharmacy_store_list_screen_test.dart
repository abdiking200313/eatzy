import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_store.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_store_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  const stores = [
    PharmacyStore(
      id: 'legacy-pharmacy',
      name: 'Legacy Pharmacy',
      address: 'Mogadishu, Somalia',
    ),
    PharmacyStore(
      id: 'hodan-pharmacy',
      name: 'Hodan Pharmacy',
      address: 'Hodan, Mogadishu',
    ),
  ];

  // The store list screen's cart badge reads a `PharmacyController` — an
  // explicit fake here (never `PharmacyController.instance`, which requires
  // a live Supabase client) mirrors how `PharmacyCatalogScreen` tests avoid
  // touching the real singleton.
  PharmacyController buildController() {
    return PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: ActivityController(),
      storage: MemoryCartStorage<PharmacyCartItem>(),
    );
  }

  testWidgets('pharmacy store list renders every pharmacy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PharmacyStoreListScreen(
          storeLoader: () async => stores,
          controller: buildController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Legacy Pharmacy'), findsOneWidget);
    expect(find.text('Hodan Pharmacy'), findsOneWidget);
    expect(find.text('Mogadishu, Somalia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pharmacy store list stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: PharmacyStoreListScreen(
              storeLoader: () async => stores,
              controller: buildController(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Legacy Pharmacy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('typing a search term debounces before filtering', (
    tester,
  ) async {
    final queryCalls = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PharmacyStoreListScreen(
          storeLoader: () async => stores,
          controller: buildController(),
          storeQuery: ({searchQuery}) async {
            queryCalls.add(searchQuery);
            return const [
              PharmacyStore(
                id: 'hodan-pharmacy',
                name: 'Hodan Pharmacy',
                address: 'Hodan, Mogadishu',
              ),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hodan');
    // Still within the debounce window — no query fired yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(queryCalls, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(queryCalls, ['hodan']);
    expect(find.text('Hodan Pharmacy'), findsOneWidget);
    expect(find.text('Legacy Pharmacy'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Legacy Pharmacy'), findsOneWidget);
  });

  testWidgets('an empty search result shows a reachable, honest empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PharmacyStoreListScreen(
          storeLoader: () async => stores,
          controller: buildController(),
          storeQuery: ({searchQuery}) async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nowhere');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('No pharmacies match "nowhere".'), findsOneWidget);
  });

  testWidgets('tapping a pharmacy navigates to its scoped catalog route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.pharmacy,
      routes: [
        GoRoute(
          path: AppRoutes.pharmacy,
          builder: (_, _) => PharmacyStoreListScreen(
            storeLoader: () async => stores,
            controller: buildController(),
          ),
        ),
        GoRoute(
          path: AppRoutes.pharmacyStore,
          builder: (_, state) => Scaffold(
            body: Text(
              'storeId=${state.pathParameters['storeId']} '
              'name=${state.uri.queryParameters['name']}',
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.pharmacyCart,
          builder: (_, _) => const Scaffold(body: Text('cart')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hodan Pharmacy'));
    await tester.pumpAndSettle();

    expect(
      find.text('storeId=hodan-pharmacy name=Hodan Pharmacy'),
      findsOneWidget,
    );
  });
}
