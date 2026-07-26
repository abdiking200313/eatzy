import 'package:chowflow/features/categories/models/category.dart';
import 'package:chowflow/features/categories/presentation/categories_screen.dart';
import 'package:chowflow/features/home/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('simple category screen renders from one file', (tester) async {
    final categories = Future.value(const [
      Category(id: 'food', name: 'Food', iconUrl: ''),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: CategoriesScreen(
          showBackButton: false,
          categoriesFuture: categories,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('pushed category screen shows a back control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoriesScreen(
          categoriesFuture: Future.value(const <Category>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('section header supports an optional action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SectionHeader(title: 'Orders')),
      ),
    );

    expect(find.text('Orders'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
