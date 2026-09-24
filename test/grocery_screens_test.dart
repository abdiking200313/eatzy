import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/grocery/presentation/grocery_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  GroceryController buildController({
    GroceryRepository repository = const SeededGroceryRepository(),
  }) {
    return GroceryController(
      repository: repository,
      storage: MemoryCartStorage<GroceryCartLine>(),
    );
  }

  Widget buildApp(GroceryController controller) {
    final router = GoRouter(
      initialLocation: '/grocery',
      routes: [
        GoRoute(
          path: '/grocery',
          builder: (_, _) => GroceryScreen(controller: controller),
        ),
        GoRoute(
          path: '/grocery/stores/:storeId',
          builder: (_, state) => GroceryStoreScreen(
            storeId: state.pathParameters['storeId']!,
            controller: controller,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets(
    'the store list renders every seeded store by name, and searching '
    'filters stores by name',
    (tester) async {
      await tester.pumpWidget(buildApp(buildController()));
      await tester.pumpAndSettle();

      expect(find.text('Bakaal Fresh'), findsOneWidget);
      expect(find.text('Suuqa Hamar'), findsOneWidget);
      // The old flattened feed showed every store's products up front; the
      // store list should not.
      expect(find.text('Bananas'), findsNothing);
      expect(find.text('Eggs'), findsNothing);

      await tester.enterText(find.byType(TextField), 'hamar');
      await tester.pumpAndSettle();

      expect(find.text('Suuqa Hamar'), findsOneWidget);
      expect(find.text('Bakaal Fresh'), findsNothing);
    },
  );

  testWidgets(
    'tapping a store opens a catalog scoped to just that store, searchable '
    'by product name',
    (tester) async {
      await tester.pumpWidget(buildApp(buildController()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bakaal Fresh'));
      await tester.pumpAndSettle();

      // Only Bakaal Fresh's products are shown, not Suuqa Hamar's.
      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Basmati rice'), findsOneWidget);
      expect(find.text('Eggs'), findsNothing);
      expect(find.text('Potatoes'), findsNothing);

      await tester.enterText(find.byType(TextField), 'rice');
      await tester.pumpAndSettle();

      expect(find.text('Basmati rice'), findsOneWidget);
      expect(find.text('Bananas'), findsNothing);
    },
  );

  testWidgets('tapping a product opens its details page, which adds the picked '
      'weight to the cart', (tester) async {
    final controller = buildController();
    await tester.pumpWidget(buildApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bakaal Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bananas'));
    await tester.pumpAndSettle();

    expect(find.text('Sold by weight, in 0.5 kg steps.'), findsOneWidget);
    expect(find.text('0.5 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(find.text('1 kg'), findsOneWidget);

    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();

    final line = controller.cart.single;
    expect(line.product.id, 'bakaal-bananas');
    expect(line.quantity, 1.0);
  });

  testWidgets('pulling to refresh reloads the grocery catalog', (tester) async {
    final repository = _CountingGroceryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: GroceryScreen(
          controller: buildController(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
  });

  test(
    'products parse their embedded category and survive a cart round-trip',
    () {
      final product = GroceryProduct.fromMap({
        'id': 'p1',
        'store_id': 's1',
        'name': 'Bananas',
        'unit_price': 150,
        'pricing_unit': 'kilogram',
        'quantity_step': 0.5,
        'available_quantity': 10,
        'low_stock_threshold': 3,
        'grocery_categories': {'name': 'Fruits & vegetables', 'sort_order': 1},
      });
      expect(product.categoryName, 'Fruits & vegetables');
      expect(product.categorySortOrder, 1);

      final restored = GroceryProduct.fromJson(product.toJson());
      expect(restored.categoryName, 'Fruits & vegetables');
      expect(restored.categorySortOrder, 1);
    },
  );

  test('groupByCategory orders sections by sort order, "Other" last', () {
    GroceryProduct product(String name, String? category, int sortOrder) =>
        GroceryProduct(
          id: name,
          storeId: 's1',
          name: name,
          description: '',
          unitPrice: 100,
          pricingUnit: GroceryPricingUnit.each,
          stockState: GroceryStockState.inStock,
          availableQuantity: 10,
          icon: '🛒',
          categoryName: category,
          categorySortOrder: sortOrder,
        );

    final sections = groupByCategory([
      product('Bread', 'Bread & bakery', 5),
      product('Mystery box', null, 0),
      product('Apples', 'Fruits & vegetables', 1),
      product('Baguette', 'Bread & bakery', 5),
    ]);

    expect(sections.map((s) => s.name), [
      'Fruits & vegetables',
      'Bread & bakery',
      'Other',
    ]);
    expect(sections[1].products.map((p) => p.name), ['Bread', 'Baguette']);
  });
}

class _CountingGroceryRepository implements GroceryRepository {
  int fetchCount = 0;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    fetchCount++;
    return const SeededGroceryRepository().fetchStores();
  }
}
