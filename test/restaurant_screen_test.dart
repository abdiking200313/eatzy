import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/cart/presentation/cart_controller.dart';
import 'package:chowflow/features/home/models/restaurant.dart';
import 'package:chowflow/features/restaurant/models/restaurant_menu.dart';
import 'package:chowflow/features/restaurant/presentation/restaurant_screen.dart';
import 'package:chowflow/features/restaurant/presentation/widgets/menu_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

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

  test('menu item throws instead of silently pricing at \$0.00 for an '
      'unparseable price (#62)', () {
    expect(
      () => MenuItem.fromMap({
        'id': 'item-2',
        'name': 'Mystery Item',
        'description': null,
        'price': 'not-a-number',
        'image_url': null,
        'categorie_id': 'mains',
      }),
      throwsFormatException,
    );
  });

  test(
    'menu item throws for a missing price rather than defaulting to \$0.00',
    () {
      expect(
        () => MenuItem.fromMap({
          'id': 'item-3',
          'name': 'No Price Item',
          'description': null,
          'price': null,
          'image_url': null,
          'categorie_id': 'mains',
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets('restaurant page groups and navigates categorized items', (
    tester,
  ) async {
    // A taller surface than the 800x600 default gives the bumped type
    // scale/spacing enough room so the first menu item's add-to-cart
    // control stays within the test viewport without needing a scroll.
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cartController = CartController(storage: MemoryCartStorage());
    await cartController.loadForOwner('user-1');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RestaurantScreen(
          restaurantId: restaurant.id,
          menuLoader: (_) async => menu,
          cartController: cartController,
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

    await tester.tap(find.byKey(const ValueKey('add-to-cart-burger-1')));
    await tester.pumpAndSettle();

    expect(cartController.itemCount, 1);
    expect(find.text('Classic Burger added to cart'), findsOneWidget);

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

  testWidgets('menu cards grow for narrow screens and larger text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longItem = MenuItem(
      id: 'long-item',
      name: 'A generously filled traditional Somali family platter',
      description:
          'Slow-cooked ingredients with fresh vegetables and house spices.',
      price: 12.5,
      imageUrl: '',
      categoryId: 'mains',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [MenuItemCard(item: longItem, onAddToCart: _doNothing)],
            ),
          ),
        ),
      ),
    );

    expect(find.text(longItem.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _doNothing() {}
