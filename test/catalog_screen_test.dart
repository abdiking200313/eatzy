import 'dart:async';

import 'package:chowflow/features/merchant/catalog/data/merchant_catalog_repository.dart';
import 'package:chowflow/features/merchant/catalog/models/merchant_catalog_item.dart';
import 'package:chowflow/features/merchant/catalog/presentation/catalog_item_form.dart';
import 'package:chowflow/features/merchant/catalog/presentation/catalog_screen.dart';
import 'package:chowflow/features/merchant/catalog/presentation/merchant_catalog_controller.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

/// A repository whose [fetchItems] hangs until [complete] is called -- see
/// `my_store_screen_test.dart`'s `_NeverCompletingStoreRepository` for why a
/// zero-delay fake can't deterministically exercise a loading state.
class _NeverCompletingCatalogRepository implements MerchantCatalogRepository {
  final _completer = Completer<List<MerchantCatalogItem>>();

  void complete(List<MerchantCatalogItem> items) => _completer.complete(items);

  @override
  Future<List<MerchantCatalogItem>> fetchItems({
    required MerchantVertical vertical,
    required String storeId,
  }) => _completer.future;

  @override
  Future<MerchantCatalogItem> createItem(MerchantCatalogItem draft) =>
      throw UnimplementedError();

  @override
  Future<MerchantCatalogItem> updateItem(MerchantCatalogItem item) =>
      throw UnimplementedError();

  @override
  Future<void> deleteItem({
    required MerchantVertical vertical,
    required String itemId,
  }) => throw UnimplementedError();

  @override
  Future<MerchantCatalogItem> setAvailability({
    required MerchantCatalogItem item,
    required bool isAvailable,
  }) => throw UnimplementedError();

  @override
  Future<List<PharmacyCategory>> fetchPharmacyCategories() async => const [];
}

// Widget-tests the Catalog screen's explicit loading/empty/error/loaded
// states, plus add/delete/toggle actions (ported from `merchant_app`,
// originally issue #133's acceptance criteria, unified into the main app by
// issue #232), against fake repositories.
void main() {
  const item = MerchantCatalogItem(
    id: 'item-1',
    storeId: 'store-1',
    vertical: MerchantVertical.food,
    name: 'Sambusa',
    description: 'Fried pastry with spiced filling',
    priceCents: 250,
    isAvailable: true,
  );

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('shows a loading indicator while the catalog loads', (
    tester,
  ) async {
    final repository = _NeverCompletingCatalogRepository();
    final controller = MerchantCatalogController(
      repository: repository,
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );

    await tester.pumpWidget(
      wrap(
        CatalogScreen(
          vertical: MerchantVertical.food,
          storeId: 'store-1',
          storeName: 'Zivo Diner',
          controller: controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an empty state with an add-item action', (tester) async {
    final controller = MerchantCatalogController(
      repository: FakeMerchantCatalogRepository(),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );

    await tester.pumpWidget(
      wrap(
        CatalogScreen(
          vertical: MerchantVertical.food,
          storeId: 'store-1',
          storeName: 'Zivo Diner',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No items yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add item'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when the load fails', (
    tester,
  ) async {
    final repository = FakeMerchantCatalogRepository()
      ..failureToThrow = Exception('boom');
    final controller = MerchantCatalogController(
      repository: repository,
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );

    await tester.pumpWidget(
      wrap(
        CatalogScreen(
          vertical: MerchantVertical.food,
          storeId: 'store-1',
          storeName: 'Zivo Diner',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your catalog could not be loaded. Please try again.'),
      findsOneWidget,
    );

    repository.failureToThrow = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('No items yet'), findsOneWidget);
  });

  testWidgets('lists items with price, and supports delete', (tester) async {
    final controller = MerchantCatalogController(
      repository: FakeMerchantCatalogRepository(initialItems: [item]),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );

    await tester.pumpWidget(
      wrap(
        CatalogScreen(
          vertical: MerchantVertical.food,
          storeId: 'store-1',
          storeName: 'Zivo Diner',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sambusa'), findsOneWidget);
    expect(find.text(r'$2.50'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sambusa'), findsNothing);
    expect(find.text('No items yet'), findsOneWidget);
  });

  testWidgets('toggling the switch flips availability', (tester) async {
    final controller = MerchantCatalogController(
      repository: FakeMerchantCatalogRepository(initialItems: [item]),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );

    await tester.pumpWidget(
      wrap(
        CatalogScreen(
          vertical: MerchantVertical.food,
          storeId: 'store-1',
          storeName: 'Zivo Diner',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.items.single.isAvailable, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.items.single.isAvailable, isFalse);
  });

  testWidgets('adding an item through the form appends it to the list', (
    tester,
  ) async {
    // Tall enough for the whole add-item sheet, photo field included.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MerchantCatalogController(
      repository: FakeMerchantCatalogRepository(),
      vertical: MerchantVertical.food,
      storeId: 'store-1',
    );

    await tester.pumpWidget(
      wrap(
        CatalogScreen(
          vertical: MerchantVertical.food,
          storeId: 'store-1',
          storeName: 'Zivo Diner',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the FAB (rather than any "Add item"-labelled button) since the
    // empty state behind it is also labelled "Add item".
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Cambuulo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price (USD)'),
      '3.50',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(CatalogItemForm),
        matching: find.widgetWithText(FilledButton, 'Add item'),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.items, hasLength(1));
    expect(controller.items.single.name, 'Cambuulo');
    expect(controller.items.single.priceCents, 350);
    expect(find.text('Cambuulo'), findsOneWidget);
  });
}
