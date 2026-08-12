import 'package:chowflow/features/home/models/category.dart';
import 'package:chowflow/features/home/presentation/widgets/categories_section.dart';
import 'package:chowflow/features/home/presentation/widgets/section_header.dart';
import 'package:chowflow/screens/categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('standalone category placeholder renders from one file', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CategoriesScreen(showBackButton: false)),
    );

    expect(find.text('Services'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    for (final label in ['Food', 'Pharmacy', 'Grocery', 'Cleaning']) {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('pushed category screen shows a back control', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));

    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('home category section shows an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoriesSection(
            categories: const <Category>[],
            selectedCategoryId: null,
            onCategorySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No categories found'), findsOneWidget);
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
