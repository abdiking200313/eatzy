import 'dart:async';

import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_checkout.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_checkout_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:chowflow/services/shared/data/rpc_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

/// A [PharmacyOrderRepository] fake whose [placeOrder] only resolves once
/// the test calls [complete], so a widget test can exercise a second tap
/// while the first submission is still in flight.
class _ControllablePharmacyOrderRepository implements PharmacyOrderRepository {
  int callCount = 0;
  final _pending = Completer<PlacedOrder>();

  void complete(String orderId) => _pending.complete(
    PlacedOrder(
      orderId: orderId,
      subtotal: 1000,
      deliveryFee: 250,
      tax: 0,
      total: 1250,
    ),
  );

  @override
  Future<PlacedOrder> placeOrder(PharmacyOrderRequest request) {
    callCount++;
    return _pending.future;
  }
}

void main() {
  testWidgets(
    'a double-tap on the submit button places only one pharmacy order '
    '(issue #59)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _ControllablePharmacyOrderRepository();
      final controller = PharmacyController(
        repository: const SeededPharmacyRepository(),
        orderRepository: repository,
        activityController: ActivityController(),
        storage: MemoryCartStorage<PharmacyCartItem>(),
      );
      await controller.loadProducts(
        storeId: SeededPharmacyRepository.defaultStoreId,
      );
      controller.addProduct(controller.products.first);

      await tester.pumpWidget(
        MaterialApp(home: PharmacyCheckoutScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('pharmacy-customer-name')),
        'Asha Ali',
      );
      await tester.enterText(
        find.byKey(const ValueKey('pharmacy-phone')),
        '+252 61 234 5678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('pharmacy-district')),
        'Hodan',
      );
      await tester.enterText(
        find.byKey(const ValueKey('pharmacy-address')),
        'Taleex Road, blue gate',
      );

      // Tap twice in a row before the first submission's RPC has resolved.
      await tester.tap(find.textContaining('Confirm demo order'));
      await tester.pump();
      expect(find.text('Saving order...'), findsOneWidget);

      await tester.tap(find.text('Saving order...'));
      await tester.pump();

      // Only one request ever reached the repository — the button was
      // disabled for the second tap, and PharmacyController's own
      // `isSubmitting` guard is a second line of defense either way. The
      // first submission is left in flight (never completed) so this test
      // doesn't also have to stand up a route for the post-success dialog
      // and navigation, which is outside what this test is about.
      expect(repository.callCount, 1);
    },
  );
}
