import '../../home/models/restaurant.dart';

class RestaurantMenu {
  const RestaurantMenu({required this.restaurant, required this.categories});

  final Restaurant restaurant;
  final List<MenuCategory> categories;

  int get itemCount =>
      categories.fold(0, (count, category) => count + category.items.length);
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
  final double price;
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
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');
    if (price == null || !price.isFinite || price < 0) {
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
}
