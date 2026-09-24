import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_store.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_store_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/controllers.dart';

void main() {
  group('store list', () {
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
    PharmacyController buildController() => buildPharmacyController();

    testWidgets(
      'renders every pharmacy and stays overflow-free on a narrow, large-text '
      'screen',
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
        expect(find.text('Hodan Pharmacy'), findsOneWidget);
        expect(find.text('Mogadishu, Somalia'), findsOneWidget);
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

    testWidgets(
      'an empty search result shows a reachable, honest empty state',
      (tester) async {
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
      },
    );

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
  });

  group('catalog', () {
    testWidgets('pharmacy catalog clearly explains the OTC-only scope', (
      tester,
    ) async {
      final controller = buildPharmacyController();

      await tester.pumpWidget(
        MaterialApp(
          home: PharmacyCatalogScreen(
            storeId: SeededPharmacyRepository.defaultStoreId,
            storeName: 'Pharmacy',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pharmacy'), findsOneWidget);
      expect(find.text('Over-the-counter (OTC) only'), findsOneWidget);
      expect(
        find.textContaining('does not accept prescriptions'),
        findsOneWidget,
      );
      expect(find.text('Paracetamol'), findsOneWidget);
      // The store search field's `TextField` carries its own internal
      // `Scrollable`, so the default `find.byType(Scrollable)` now matches
      // more than one widget — pin `scrollUntilVisible` to the catalog list
      // itself, same as `layout_test.dart` does.
      await tester.scrollUntilVisible(
        find.text('Out of stock'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Out of stock'), findsOneWidget);
    });

    testWidgets(
      'tapping a product opens its details page, which adds the picked '
      'quantity to the cart',
      (tester) async {
        final controller = buildPharmacyController();

        await tester.pumpWidget(
          MaterialApp(
            home: PharmacyCatalogScreen(
              storeId: SeededPharmacyRepository.defaultStoreId,
              storeName: 'Pharmacy',
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Paracetamol'));
        await tester.pumpAndSettle();

        expect(
          find.text('Everyday relief for mild pain and fever.'),
          findsOneWidget,
        );
        expect(find.text('Pain relief'), findsOneWidget);
        await tester.tap(find.byTooltip('Increase quantity'));
        await tester.tap(find.byTooltip('Increase quantity'));
        await tester.pump();
        expect(find.text('3'), findsOneWidget);

        await tester.tap(find.text('Add to cart'));
        await tester.pumpAndSettle();

        expect(find.text('Pain relief'), findsWidgets); // back on the list
        final line = controller.cartItems.single;
        expect(line.product.id, 'pain-paracetamol');
        expect(line.quantity, 3);
      },
    );

    testWidgets('pulling to refresh reloads the pharmacy catalog', (
      tester,
    ) async {
      final repository = _CountingPharmacyRepository();
      final controller = buildPharmacyController(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: PharmacyCatalogScreen(
            storeId: SeededPharmacyRepository.defaultStoreId,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.fetchCount, 1);

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

    testWidgets('typing a search term narrows this pharmacy\'s catalog', (
      tester,
    ) async {
      final controller = buildPharmacyController(
        repository: _MultiStorePharmacyRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PharmacyCatalogScreen(
            storeId: 'store-a',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vitamin A'), findsOneWidget);
      // The hero banner above the catalog list (issue #250) pushes the second
      // product row below the fold on a default test viewport — same
      // `scrollUntilVisible` pattern the OTC-scope test above uses.
      await tester.scrollUntilVisible(
        find.text('Bandages A'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Bandages A'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Vitamin');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Vitamin A'), findsOneWidget);
      expect(find.text('Bandages A'), findsNothing);
    });

    testWidgets(
      'adding a product from a different pharmacy prompts to replace the cart',
      (tester) async {
        final controller = buildPharmacyController(
          repository: _MultiStorePharmacyRepository(),
        );
        await controller.loadProducts(storeId: 'store-a');
        controller.addProduct(controller.products.first);
        expect(controller.cartItems.single.product.storeId, 'store-a');

        await tester.pumpWidget(
          MaterialApp(
            home: PharmacyCatalogScreen(
              storeId: 'store-b',
              storeName: 'Store B',
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('add-pharmacy-store-b-item')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start a new pharmacy cart?'), findsOneWidget);

        await tester.tap(find.text('Start new cart'));
        await tester.pumpAndSettle();

        expect(controller.cartItems.single.product.storeId, 'store-b');
        expect(
          find.text('Store B item added to pharmacy cart.'),
          findsOneWidget,
        );
      },
    );
  });
}

/// A [PharmacyRepository] fake backing two distinct pharmacies, used to
/// exercise store-scoping and the cross-pharmacy cart-conflict prompt.
class _MultiStorePharmacyRepository implements PharmacyRepository {
  static const _products = <PharmacyProduct>[
    PharmacyProduct(
      id: 'store-a-vitamin',
      storeId: 'store-a',
      name: 'Vitamin A',
      description: 'Store A vitamin.',
      category: 'Vitamins',
      unitPrice: 3,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'store-a-bandages',
      storeId: 'store-a',
      name: 'Bandages A',
      description: 'Store A first aid.',
      category: 'First aid',
      unitPrice: 2,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
    PharmacyProduct(
      id: 'store-b-item',
      storeId: 'store-b',
      name: 'Store B item',
      description: 'Store B essential.',
      category: 'Wellness',
      unitPrice: 5,
      stockQuantity: 10,
      saleType: PharmacySaleType.overTheCounter,
    ),
  ];

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async {
    final query = searchQuery?.trim().toLowerCase();
    final hasSearch = query != null && query.isNotEmpty;
    final matches = _products
        .where((product) => product.storeId == storeId)
        .where(
          (product) => !hasSearch || product.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
    if (offset >= matches.length) {
      return const [];
    }
    final end = (offset + limit).clamp(0, matches.length);
    return List<PharmacyProduct>.unmodifiable(matches.sublist(offset, end));
  }
}

class _CountingPharmacyRepository implements PharmacyRepository {
  int fetchCount = 0;

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    required String storeId,
    String? searchQuery,
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async {
    fetchCount++;
    return const SeededPharmacyRepository().fetchProducts(
      storeId: storeId,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }
}
