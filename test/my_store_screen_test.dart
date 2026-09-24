import 'dart:async';

import 'package:chowflow/features/merchant/store/data/merchant_store_repository.dart';
import 'package:chowflow/features/merchant/store/models/merchant_store.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:chowflow/features/merchant/store/presentation/merchant_store_controller.dart';
import 'package:chowflow/features/merchant/store/presentation/my_store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

/// A repository whose [fetchOwnStore] hangs until [complete] is called --
/// deterministically holds the screen in its loading state, the same
/// `Completer`-based technique the root app's `food_home_screen_test.dart`
/// uses, since a fake that resolves immediately races the test's `pump()`.
class _NeverCompletingStoreRepository implements MerchantStoreRepository {
  final _completer = Completer<MerchantStore?>();

  void complete(MerchantStore? store) => _completer.complete(store);

  @override
  Future<MerchantStore?> fetchOwnStore(String ownerId) => _completer.future;

  @override
  Future<MerchantStore> createStore({
    required MerchantVertical vertical,
    required String ownerId,
    required String name,
    required String location,
    String? description,
    String? imageUrl,
  }) => throw UnimplementedError();

  @override
  Future<MerchantStore> updateStore(
    MerchantStore store, {
    required String ownerId,
    required String name,
    required String location,
    required bool isOpen,
    String? description,
    String? imageUrl,
  }) => throw UnimplementedError();
}

// Widget-tests "My Store"'s explicit loading/empty/error/loaded states
// (ported from `merchant_app`, originally issue #133's acceptance criteria,
// unified into the main app by issue #232) against a fake repository -- no
// Supabase network access in this sandbox.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows a loading indicator while the store loads', (
    tester,
  ) async {
    final repository = _NeverCompletingStoreRepository();
    final controller = MerchantStoreController(repository: repository);

    await tester.pumpWidget(
      wrap(MyStoreScreen(ownerId: 'merchant-1', controller: controller)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Resolving lets the screen move on, proving it was genuinely waiting
    // rather than stuck.
    repository.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'shows the create-store empty state when the merchant has no store',
    (tester) async {
      final controller = MerchantStoreController(
        repository: FakeMerchantStoreRepository(),
      );

      await tester.pumpWidget(
        wrap(MyStoreScreen(ownerId: 'merchant-1', controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text("You don't have a store yet"), findsOneWidget);
      expect(find.text('Create store'), findsOneWidget);
    },
  );

  testWidgets('shows an error state with retry when the load fails', (
    tester,
  ) async {
    final repository = FakeMerchantStoreRepository()
      ..failureToThrow = Exception('boom');
    final controller = MerchantStoreController(repository: repository);

    await tester.pumpWidget(
      wrap(MyStoreScreen(ownerId: 'merchant-1', controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your store could not be loaded. Please try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);

    // Retrying with a working repository recovers into the loaded state.
    repository.failureToThrow = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text("You don't have a store yet"), findsOneWidget);
  });

  testWidgets('shows the edit form once a store is loaded', (tester) async {
    const store = MerchantStore(
      id: 'restaurant-1',
      vertical: MerchantVertical.food,
      name: 'Zivo Diner',
      location: '123 Main St',
      isOpen: true,
      description: 'Somali comfort food',
    );
    final controller = MerchantStoreController(
      repository: FakeMerchantStoreRepository(initialStore: store),
    );

    await tester.pumpWidget(
      wrap(MyStoreScreen(ownerId: 'merchant-1', controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food store'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Store name'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Manage catalog'), findsOneWidget);
  });

  testWidgets('editing and saving updates the store profile', (tester) async {
    // Tall enough for the whole form, photo field included.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const store = MerchantStore(
      id: 'restaurant-1',
      vertical: MerchantVertical.food,
      name: 'Zivo Diner',
      location: '123 Main St',
      isOpen: true,
    );
    final controller = MerchantStoreController(
      repository: FakeMerchantStoreRepository(initialStore: store),
    );

    await tester.pumpWidget(
      wrap(MyStoreScreen(ownerId: 'merchant-1', controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store name'),
      'Zivo Diner Renamed',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(controller.store!.name, 'Zivo Diner Renamed');
    expect(find.text('Store saved.'), findsOneWidget);
  });
}
