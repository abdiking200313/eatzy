import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/grocery/presentation/grocery_screen.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:chowflow/widgets/add_to_cart_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'grocery catalog uses green service cards and shared cart action',
    (tester) async {
      final controller = GroceryController(
        repository: const SeededGroceryRepository(),
        activityController: ActivityController(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.grocery,
            child: GroceryScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AddToCartButton), findsWidgets);
      expect(find.byIcon(Icons.add_shopping_cart_rounded), findsWidgets);
      expect(find.text('Bananas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pharmacy catalog stays overflow-free with the shared cart action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = PharmacyController(
        repository: const SeededPharmacyRepository(),
        activityController: ActivityController(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.pharmacy,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(1.3),
              ),
              child: PharmacyCatalogScreen(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AddToCartButton), findsWidgets);
      expect(find.byIcon(Icons.add_shopping_cart_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
