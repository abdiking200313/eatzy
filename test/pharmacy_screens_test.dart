import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_catalog_screen.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  testWidgets('pharmacy catalog clearly explains the OTC-only scope', (
    tester,
  ) async {
    final controller = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: ActivityController(),
      storage: MemoryCartStorage<PharmacyCartItem>(),
    );

    await tester.pumpWidget(
      MaterialApp(home: PharmacyCatalogScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pharmacy'), findsOneWidget);
    expect(find.text('Over-the-counter (OTC) only'), findsOneWidget);
    expect(
      find.textContaining('does not accept prescriptions'),
      findsOneWidget,
    );
    expect(find.text('Paracetamol'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Out of stock'), 300);
    expect(find.text('Out of stock'), findsOneWidget);
  });
}
