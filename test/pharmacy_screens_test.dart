import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
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

  testWidgets('pulling to refresh reloads the pharmacy catalog', (
    tester,
  ) async {
    final repository = _CountingPharmacyRepository();
    final controller = PharmacyController(
      repository: repository,
      activityController: ActivityController(),
      storage: MemoryCartStorage<PharmacyCartItem>(),
    );

    await tester.pumpWidget(
      MaterialApp(home: PharmacyCatalogScreen(controller: controller)),
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

class _CountingPharmacyRepository implements PharmacyRepository {
  int fetchCount = 0;

  @override
  Future<List<PharmacyProduct>> fetchProducts({
    int limit = pharmacyProductsPageSize,
    int offset = 0,
  }) async {
    fetchCount++;
    return const SeededPharmacyRepository().fetchProducts(
      limit: limit,
      offset: offset,
    );
  }
}
