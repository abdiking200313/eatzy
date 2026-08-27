import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/home/data/restaurant_repository.dart';
import 'package:chowflow/features/home/models/restaurant.dart';
import 'package:chowflow/services/food/presentation/food_explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRestaurantRepository implements RestaurantRepository {
  _FakeRestaurantRepository(this._restaurants);

  final List<Restaurant> _restaurants;
  String? capturedSearchQuery;
  String? capturedCategoryId;

  @override
  Future<List<Restaurant>> fetchRestaurants({
    String? searchQuery,
    String? categoryId,
  }) async {
    capturedSearchQuery = searchQuery;
    capturedCategoryId = categoryId;
    return _restaurants;
  }
}

void main() {
  testWidgets('food Explore lists restaurants rather than service modules', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodExploreScreen(
          restaurants: Future.value(const [
            Restaurant(
              id: 'restaurant-1',
              name: 'Mogadishu Kitchen',
              description: 'Somali favourites',
              logoUrl: '',
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore restaurants'), findsOneWidget);
    expect(find.text('Mogadishu Kitchen'), findsOneWidget);
    expect(find.text('Grocery'), findsNothing);
    expect(find.text('Pharmacy'), findsNothing);
  });

  testWidgets(
    'food Explore stays overflow-free on a narrow, large-text screen',
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
            child: FoodExploreScreen(
              restaurants: Future.value(const [
                Restaurant(
                  id: 'restaurant-1',
                  name: 'A generously long restaurant name that keeps on going',
                  description:
                      'A long description of Somali favourites with '
                      'plenty of detail about what is on the menu today.',
                  logoUrl: '',
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a category-scoped explore view titles itself and filters via the repository',
    (tester) async {
      final repository = _FakeRestaurantRepository(const [
        Restaurant(
          id: 'restaurant-2',
          name: 'Rice Bowl',
          description: 'Rice specialists',
          logoUrl: '',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodExploreScreen(
            repository: repository,
            categoryId: 'rice',
            categoryName: 'Rice dishes',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rice dishes'), findsOneWidget);
      expect(find.text('Explore restaurants'), findsNothing);
      expect(find.text('Rice Bowl'), findsOneWidget);
      expect(repository.capturedCategoryId, 'rice');
    },
  );

  testWidgets('an empty category result shows a category-aware empty state', (
    tester,
  ) async {
    final repository = _FakeRestaurantRepository(const []);

    await tester.pumpWidget(
      MaterialApp(
        home: FoodExploreScreen(
          repository: repository,
          categoryId: 'rice',
          categoryName: 'Rice dishes',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No restaurants found in this category.'), findsOneWidget);
  });
}
