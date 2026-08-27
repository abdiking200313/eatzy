import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/home/models/category.dart';
import 'package:chowflow/services/food/presentation/food_categories_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('tapping a category card navigates to a filtered explore view', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/food/categories',
      routes: [
        GoRoute(
          path: '/food/categories',
          builder: (_, _) =>
              FoodCategoriesScreen(categories: Future.value(categories)),
        ),
        GoRoute(
          path: '/food/explore',
          builder: (_, state) => Scaffold(
            body: Text(
              'categoryId=${state.uri.queryParameters['categoryId']} '
              'categoryName=${state.uri.queryParameters['categoryName']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rice dishes'));
    await tester.pumpAndSettle();

    expect(
      find.text('categoryId=rice categoryName=Rice dishes'),
      findsOneWidget,
    );
  });
}
