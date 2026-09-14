import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/services/grocery/presentation/grocery_screen.dart';
import 'package:chowflow/services/grocery/presentation/grocery_store_screen.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import 'package:chowflow/widgets/add_to_cart_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/controllers.dart';

void main() {
  testWidgets(
    'grocery store catalog uses green service cards and shared cart action',
    (tester) async {
      final controller = buildGroceryController();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.grocery,
            child: GroceryStoreScreen(
              storeId: 'bakaal-fresh',
              controller: controller,
            ),
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
      final controller = buildPharmacyController();

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
              child: PharmacyCatalogScreen(
                storeId: SeededPharmacyRepository.defaultStoreId,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The store search field pushes the OTC notice/heading tall enough at
      // this text scale that no product card is on screen without
      // scrolling — mirrors `pharmacy_screens_test.dart`'s
      // `scrollUntilVisible` fix, pinned to the catalog list since the
      // search field's own `TextField` adds a second `Scrollable` to the
      // default finder.
      await tester.scrollUntilVisible(
        find.byType(AddToCartButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(AddToCartButton), findsWidgets);
      expect(find.byIcon(Icons.add_shopping_cart_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pharmacy catalog stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = buildPharmacyController();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.pharmacy,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.4),
              ),
              child: PharmacyCatalogScreen(
                storeId: SeededPharmacyRepository.defaultStoreId,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Over-the-counter (OTC) only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grocery catalog stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = buildGroceryController();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.grocery,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.4),
              ),
              child: GroceryScreen(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Somali stores near you'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grocery store catalog stays overflow-free on a narrow, large-text '
    'screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = buildGroceryController();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ZivoServiceTheme(
            serviceId: ServiceId.grocery,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.4),
              ),
              child: GroceryStoreScreen(
                storeId: 'bakaal-fresh',
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bananas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
