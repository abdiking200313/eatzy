import 'dart:async';

import 'package:chowflow/features/merchant/orders/data/merchant_orders_repository.dart';
import 'package:chowflow/features/merchant/orders/models/merchant_order.dart';
import 'package:chowflow/features/merchant/orders/presentation/orders_screen.dart';
import 'package:chowflow/features/merchant/store/data/merchant_store_repository.dart';
import 'package:chowflow/features/merchant/store/models/merchant_store.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:chowflow/features/merchant/store/presentation/merchant_store_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

/// A repository whose [fetchOrders] hangs until [complete] is called -- see
/// `my_store_screen_test.dart`'s `_NeverCompletingStoreRepository` for why a
/// zero-delay fake can't deterministically exercise a loading state.
class _NeverCompletingOrdersRepository implements MerchantOrdersRepository {
  final _completer = Completer<List<MerchantOrder>>();

  void complete(List<MerchantOrder> orders) => _completer.complete(orders);

  @override
  Future<List<MerchantOrder>> fetchOrders({
    required MerchantVertical vertical,
    required String storeId,
  }) => _completer.future;

  @override
  Future<String> advanceOrderStatus({
    required MerchantVertical vertical,
    required String orderId,
    required String newStatus,
  }) => throw UnimplementedError();
}

/// A repository whose [fetchOwnStore] hangs until [complete] is called, the
/// same technique as [_NeverCompletingOrdersRepository] above, for
/// deterministically exercising the store-resolution loading state.
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

// Widget-tests the Orders screen's explicit loading/empty/error/loaded
// states, the "no store yet" state, and accept/advance actions on a real
// order (ported from `merchant_app`, originally issue #134's acceptance
// criteria, unified into the main app by issue #232), against fake
// repositories -- no Supabase network access in this sandbox.
void main() {
  const store = MerchantStore(
    id: 'store-1',
    vertical: MerchantVertical.food,
    name: 'Zivo Diner',
    location: 'Hodan, Mogadishu',
    isOpen: true,
  );

  final confirmedOrder = MerchantOrder.fromMap({
    'id': 'order-1',
    'status': 'confirmed',
    'created_at': '2026-09-01T12:00:00Z',
    'subtotal': 500,
    'delivery_fee': 499,
    'tax': 50,
    'total': 1049,
    'recipient_name': 'Amina',
    'phone': '+252-61-000-0000',
    'street': 'Main St',
    'district': 'Hodan',
    'city': 'Mogadishu',
    'food_order_items': [
      {'id': 1, 'item_name': 'Sambusa', 'quantity': 2, 'unit_price': 250},
    ],
  }, vertical: MerchantVertical.food);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  MerchantStoreController storeControllerWith(MerchantStore? initial) =>
      MerchantStoreController(
        repository: FakeMerchantStoreRepository(initialStore: initial),
      );

  testWidgets('shows a loading indicator while the store loads', (
    tester,
  ) async {
    final storeRepository = _NeverCompletingStoreRepository();
    final storeController = MerchantStoreController(
      repository: storeRepository,
    );
    await tester.pumpWidget(
      wrap(
        OrdersScreen(
          ownerId: 'merchant-1',
          storeController: storeController,
          ordersRepository: FakeMerchantOrdersRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    storeRepository.complete(store);
    await tester.pumpAndSettle();
    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets("shows a 'set up your store' state with no store", (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        OrdersScreen(
          ownerId: 'merchant-1',
          storeController: storeControllerWith(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your store first'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while orders load', (tester) async {
    final ordersRepository = _NeverCompletingOrdersRepository();
    await tester.pumpWidget(
      wrap(
        OrdersScreen(
          ownerId: 'merchant-1',
          storeController: storeControllerWith(store),
          ordersRepository: ordersRepository,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    ordersRepository.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an empty state with no orders', (tester) async {
    await tester.pumpWidget(
      wrap(
        OrdersScreen(
          ownerId: 'merchant-1',
          storeController: storeControllerWith(store),
          ordersRepository: FakeMerchantOrdersRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when the load fails', (
    tester,
  ) async {
    final ordersRepository = FakeMerchantOrdersRepository()
      ..failureToThrow = Exception('boom');
    await tester.pumpWidget(
      wrap(
        OrdersScreen(
          ownerId: 'merchant-1',
          storeController: storeControllerWith(store),
          ordersRepository: ordersRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your orders could not be loaded. Please try again.'),
      findsOneWidget,
    );

    ordersRepository.failureToThrow = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('lists an order and supports pull-to-refresh', (tester) async {
    final ordersRepository = FakeMerchantOrdersRepository(
      initialOrders: [confirmedOrder],
    );
    await tester.pumpWidget(
      wrap(
        OrdersScreen(
          ownerId: 'merchant-1',
          storeController: storeControllerWith(store),
          ordersRepository: ordersRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Order #'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Order #'), findsOneWidget);
  });

  testWidgets('tapping an order opens detail and accepting it advances it', (
    tester,
  ) async {
    final ordersRepository = FakeMerchantOrdersRepository(
      initialOrders: [confirmedOrder],
    );
    await tester.pumpWidget(
      wrap(
        OrdersScreen(
          ownerId: 'merchant-1',
          storeController: storeControllerWith(store),
          ordersRepository: ordersRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Order #'));
    await tester.pumpAndSettle();

    // Line items and address/contact info are shown on the detail screen.
    expect(find.text('Sambusa'), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.textContaining('Main St'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Accept order'));
    await tester.pumpAndSettle();

    // The pill on the detail screen reflects the new status immediately.
    expect(find.text('Preparing'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // And the list, backed by the same controller, shows it too.
    expect(find.text('Preparing'), findsOneWidget);
  });

  testWidgets(
    'a rejected transition shows a clear error banner, not a silent no-op',
    (tester) async {
      // The UI itself only ever offers legal next steps, so this simulates
      // the server rejecting the call anyway (e.g. a concurrent change) --
      // exactly the "illegal transition surfaces a clear error, not a
      // silent no-op" acceptance criterion, exercised end-to-end through the
      // screen rather than the repository directly.
      final ordersRepository = FakeMerchantOrdersRepository(
        initialOrders: [confirmedOrder],
      );
      await tester.pumpWidget(
        wrap(
          OrdersScreen(
            ownerId: 'merchant-1',
            storeController: storeControllerWith(store),
            ordersRepository: ordersRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Order #'));
      await tester.pumpAndSettle();

      // Set the failure only now, so the initial order list load (which
      // also goes through this fake) still succeeds.
      ordersRepository.failureToThrow = const OrderStatusTransitionException(
        'Illegal food order status transition: confirmed -> preparing',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Accept order'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Illegal food order status transition: confirmed -> preparing',
        ),
        findsOneWidget,
      );
      // The status must not have silently changed.
      expect(find.text('Confirmed'), findsWidgets);
    },
  );
}
