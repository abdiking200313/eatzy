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
}

class _CountingGroceryRepository implements GroceryRepository {
  int fetchCount = 0;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    fetchCount++;
    return const SeededGroceryRepository().fetchStores();
  }
}
