import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_checkout_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  testWidgets(
    'submitting an incomplete grocery checkout shows errors inline below '
    'each invalid field, not just a generic banner',
    (tester) async {
      final controller = GroceryController(
        repository: const SeededGroceryRepository(),
        activityController: ActivityController(),
        storage: MemoryCartStorage<GroceryCartLine>(),
      );
      await controller.load();
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
}
