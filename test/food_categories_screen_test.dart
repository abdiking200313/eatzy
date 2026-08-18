import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/home/models/category.dart';
import 'package:chowflow/services/food/presentation/food_categories_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const categories = [
    Category(id: 'rice', name: 'Rice dishes', iconUrl: ''),
    Category(id: 'grill', name: 'Grilled favourites', iconUrl: ''),
  ];

  testWidgets('food categories renders a white-card grid of categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: FoodCategoriesScreen(categories: Future.value(categories)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rice dishes'), findsOneWidget);
    expect(find.text('Grilled favourites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'food categories stays overflow-free on a narrow, large-text screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: FoodCategoriesScreen(categories: Future.value(categories)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rice dishes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
