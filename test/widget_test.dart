import 'dart:async';

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

    expect(find.text('Categories'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    for (final label in ['Food', 'Pharmacy', 'Grocery', 'Cleaner']) {
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

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('home category section shows fetch errors in the UI', (
    tester,
  ) async {
    final categoriesCompleter = Completer<List<Category>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoriesSection(
            categoriesFuture: categoriesCompleter.future,
            selectedCategoryId: null,
            onCategorySelected: (_) {},
          ),
        ),
      ),
    );

    categoriesCompleter.completeError(StateError('category request failed'));
    await tester.pump();

    expect(find.text('Unable to load categories'), findsOneWidget);
    expect(find.textContaining('category request failed'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
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
