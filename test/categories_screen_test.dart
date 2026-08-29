import 'package:chowflow/screens/categories.dart';
import 'package:chowflow/services/food/models/category.dart';
import 'package:chowflow/services/food/presentation/widgets/categories_section.dart';
import 'package:chowflow/services/food/presentation/widgets/section_header.dart';
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
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    for (final label in ['Food', 'Pharmacy', 'Grocery']) {
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

  testWidgets(
    'services list stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: const CategoriesScreen(showBackButton: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
