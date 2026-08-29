import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/grocery/presentation/grocery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  testWidgets('pulling to refresh reloads the grocery catalog', (tester) async {
    final repository = _CountingGroceryRepository();
    final controller = GroceryController(
      repository: repository,
      storage: MemoryCartStorage<GroceryCartLine>(),
    );

    await tester.pumpWidget(
      MaterialApp(home: GroceryScreen(controller: controller)),
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

class _CountingGroceryRepository implements GroceryRepository {
  int fetchCount = 0;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    fetchCount++;
    return const SeededGroceryRepository().fetchStores();
  }
}
