import 'restaurant.dart';

class RestaurantMenu {
  const RestaurantMenu({required this.restaurant, required this.categories});

  final Restaurant restaurant;
  final List<MenuCategory> categories;

  int get itemCount =>
      categories.fold(0, (count, category) => count + category.items.length);

  /// JSON-encodable form for `QueryCache`; round-trips through [fromMap].
  Map<String, dynamic> toMap() => {
    'restaurant': restaurant.toMap(),
    'categories': [for (final category in categories) category.toMap()],
  };

  factory RestaurantMenu.fromMap(Map<String, dynamic> map) {
    return RestaurantMenu(
      restaurant: Restaurant.fromMap(
        Map<String, dynamic>.from(map['restaurant'] as Map),
      ),
      categories: List.unmodifiable([
        for (final category in map['categories'] as List)
          MenuCategory.fromMap(Map<String, dynamic>.from(category as Map)),
      ]),
    );
  }
}

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<MenuItem> items;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'items': [for (final item in items) item.toMap()],
  };

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Other',
      items: List.unmodifiable([
        for (final item in map['items'] as List)
          MenuItem.fromMap(Map<String, dynamic>.from(item as Map)),
      ]),
    );
  }
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
  });

  final String id;
  final String name;
  final String description;

  /// Price in integer cents (smallest currency unit) — see issue #8. Convert
  /// to decimal dollars only at display time, via
  /// `AppMoney.formatCents(price)`.
  final int price;
  final String imageUrl;
  final String categoryId;

  /// Throws a [FormatException] when `price` is missing or unparseable
  /// rather than defaulting to `0` (see #62): a menu item silently priced at
  /// $0.00 could be added to cart for free client-side even though the
  /// server would still charge the real amount, which is worse than not
  /// showing the item at all. [RestaurantMenuRepository] catches this per
  /// item and excludes just that item from the menu, see
  /// `restaurant_menu_repository.dart`.
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final price = rawPrice is num
        ? rawPrice.round()
        : int.tryParse(rawPrice?.toString() ?? '');
    if (price == null || price < 0) {
      throw FormatException(
        'Invalid menu item price for ${map['id']}: $rawPrice',
      );
    }

    return MenuItem(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Unnamed item',
      description: map['description'] as String? ?? '',
      price: price,
      imageUrl: map['image_url'] as String? ?? '',
      categoryId: map['categorie_id']?.toString() ?? 'uncategorized',
    );
  }

  /// Inverse of [MenuItem.fromMap], using the same column names.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'image_url': imageUrl,
    'categorie_id': categoryId,
  };
}
