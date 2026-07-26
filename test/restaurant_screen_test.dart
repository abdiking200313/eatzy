import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/home/models/restaurant.dart';
import 'package:chowflow/features/restaurant/models/restaurant_menu.dart';
import 'package:chowflow/features/restaurant/presentation/restaurant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const restaurant = Restaurant(
    id: 'restaurant-1',
    name: 'Test Kitchen',
    description: 'Fresh food made daily',
    logoUrl: '',
  );

  const menu = RestaurantMenu(
    restaurant: restaurant,
    categories: [
      MenuCategory(
        id: 'burgers',
        name: 'Burgers',
        items: [
          MenuItem(
            id: 'burger-1',
            name: 'Classic Burger',
            description: 'Beef, cheese, and house sauce',
            price: 5.5,
            imageUrl: '',
            categoryId: 'burgers',
          ),
        ],
      ),
      MenuCategory(
        id: 'drinks',
        name: 'Drinks',
        items: [
          MenuItem(
            id: 'drink-1',
            name: 'Fresh Lemonade',
            description: 'Lemon and mint',
            price: 1,
            imageUrl: '',
            categoryId: 'drinks',
          ),
        ],
      ),
    ],
  );

  test('menu item parses numeric strings from Supabase', () {
    final item = MenuItem.fromMap({
      'id': 'item-1',
      'name': 'Chicken Wrap',
      'description': null,
      'price': '4.50',
      'image_url': null,
      'categorie_id': 'wraps',
    });

    expect(item.price, 4.5);
    expect(item.description, isEmpty);
    expect(item.categoryId, 'wraps');
  });

  testWidgets('restaurant page groups and navigates categorized items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RestaurantScreen(
          restaurantId: restaurant.id,
          menuLoader: (_) async => menu,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Kitchen'), findsWidgets);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('2 categories'), findsOneWidget);
    expect(find.text('Classic Burger'), findsOneWidget);
    expect(find.text(r'$5.50'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Burgers'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Drinks'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Drinks'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Lemonade'), findsOneWidget);
    expect(find.text(r'$1.00'), findsOneWidget);
  });

  testWidgets('restaurant page shows a useful menu error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RestaurantScreen(
          restaurantId: restaurant.id,
          menuLoader: (_) => Future.error(StateError('failed')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not load this menu'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
