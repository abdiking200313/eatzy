import 'dart:async';

import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_checkout_screen.dart';
import 'package:chowflow/services/shared/data/rpc_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/controllers.dart';

/// A [GroceryOrderRepository] fake whose [placeOrder] only resolves once
/// the test calls [complete], so a widget test can exercise a second tap
/// while the first submission is still in flight.
class _ControllableGroceryOrderRepository implements GroceryOrderRepository {
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
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request) {
    callCount++;
    return _pending.future;
  }
}

void main() {
  testWidgets(
    'submitting an incomplete grocery checkout shows errors inline below '
    'each invalid field, not just a generic banner',
    (tester) async {
      final controller = await buildLoadedGroceryController();
      final product = controller.stores
          .expand((store) => store.products)
          .firstWhere((product) => product.isAvailable);
      controller.addProduct(product);

      await tester.pumpWidget(
        MaterialApp(home: GroceryCheckoutScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Confirm demo order'));
      await tester.pumpAndSettle();

      // Each invalid field carries its own inline error below it, mirroring
      // pharmacy checkout's errorText pattern, instead of one generic list.
      expect(find.text('Enter the recipient name.'), findsOneWidget);
      expect(find.text('Enter a valid phone number.'), findsOneWidget);
      expect(find.text('Enter a street or landmark.'), findsOneWidget);
      expect(find.text('Enter a district.'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Choose a delivery slot.'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Choose a delivery slot.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Choose a substitution preference.'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Choose a substitution preference.'), findsOneWidget);

      // The old generic "Please complete the following:" banner is gone.
      expect(find.text('Please complete the following:'), findsNothing);
    },
  );

  testWidgets('a double-tap on the submit button places only one grocery order '
      '(issue #59)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _ControllableGroceryOrderRepository();
    final controller = await buildLoadedGroceryController(
      orderRepository: repository,
    );
    final product = controller.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.isAvailable);
    controller.addProduct(product);

    await tester.pumpWidget(
      MaterialApp(home: GroceryCheckoutScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Amina');
    await tester.enterText(find.byType(TextField).at(1), '+252 61 234 5678');
    await tester.enterText(find.byType(TextField).at(2), 'Near Taleex Road');
    await tester.enterText(find.byType(TextField).at(3), 'Hodan');
    await tester.tap(find.byType(RadioListTile<GroceryDeliverySlot>).first);
    await tester.tap(
      find.byType(RadioListTile<GrocerySubstitutionPreference>).first,
    );
    await tester.pumpAndSettle();

    // Tap twice in a row before the first submission's RPC has resolved.
    await tester.tap(find.textContaining('Confirm demo order'));
    await tester.pump();
    expect(find.text('Saving order...'), findsOneWidget);

    await tester.tap(find.text('Saving order...'));
    await tester.pump();

    // Only one request ever reached the repository — the button was
    // disabled for the second tap, and GroceryController's own
    // `isSubmitting` guard is a second line of defense either way. The
    // first submission is left in flight (never completed) so this test
    // doesn't also have to stand up a route for the post-success dialog
    // and navigation, which is outside what this test is about.
    expect(repository.callCount, 1);
  });
}
