import 'restaurant.dart';

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

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];

    return MenuItem(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Unnamed item',
      description: map['description'] as String? ?? '',
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '') ?? 0,
      imageUrl: map['image_url'] as String? ?? '',
      categoryId: map['categorie_id']?.toString() ?? 'uncategorized',
    );
  }
}
