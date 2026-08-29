import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/models/restaurant.dart';
import '../models/restaurant_menu.dart';

class RestaurantMenuRepository {
  RestaurantMenuRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<RestaurantMenu> fetchMenu(String restaurantId) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('restaurants')
          .select('id, name, description, logo_url')
          .eq('id', restaurantId)
          .single(),
      _client
          .from('menu_items')
          .select(
            'id, name, description, price, image_url, categorie_id, '
            'item_categories(id, name)',
          )
          .eq('restaurant_id', restaurantId)
          .order('name'),
    ]);

    final restaurant = Restaurant.fromMap(
      Map<String, dynamic>.from(results.first as Map),
    );
    final rows = (results.last as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);

    return RestaurantMenu(
      restaurant: restaurant,
      categories: _groupItemsByCategory(rows),
    );
  }

  List<MenuCategory> _groupItemsByCategory(List<Map<String, dynamic>> rows) {
    final categoryNames = <String, String>{};
    final groupedItems = <String, List<MenuItem>>{};

    for (final row in rows) {
      final MenuItem item;
      try {
        item = MenuItem.fromMap(row);
      } on FormatException catch (error, stackTrace) {
        // Exclude just this item rather than failing the whole menu load
        // (see #62) — a bad price must never fall back to $0.00 (a real
        // charge with no on-screen warning), but nor should it block every
        // other item on the menu from being shown.
        debugPrint(
          'Skipping malformed menu_items row (id: ${row['id']}): '
          '$error\n$stackTrace',
        );
        continue;
      }
      final category = row['item_categories'];
      final categoryName = category is Map
          ? category['name']?.toString().trim()
          : null;

      categoryNames[item.categoryId] = categoryName?.isNotEmpty == true
          ? categoryName!
          : 'Other';
      groupedItems.putIfAbsent(item.categoryId, () => []).add(item);
    }

    final categories = groupedItems.entries
        .map(
          (entry) => MenuCategory(
            id: entry.key,
            name: categoryNames[entry.key] ?? 'Other',
            items: List.unmodifiable(entry.value),
          ),
        )
        .toList();

    categories.sort((a, b) {
      if (a.name == 'Other') return 1;
      if (b.name == 'Other') return -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return List.unmodifiable(categories);
  }
}
