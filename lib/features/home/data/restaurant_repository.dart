import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Cap applied to the new search/category-filtered query paths below so
  /// they can't become another unbounded query (a separately tracked issue
  /// for the plain unfiltered listing, which this leaves untouched).
  static const int _filteredResultLimit = 30;

  /// Fetches restaurants, optionally narrowed by a case-insensitive [name]
  /// substring match and/or restaurants that have at least one menu item in
  /// [categoryId] (an `item_categories.id`, joined via the existing
  /// `menu_items.categorie_id` relationship also used by
  /// `RestaurantMenuRepository`/`CategoryRepository`).
  Future<List<Restaurant>> fetchRestaurants({
    String? searchQuery,
    String? categoryId,
  }) async {
    final query = searchQuery?.trim();
    final hasSearch = query != null && query.isNotEmpty;
    final category = categoryId;
    final hasCategory = category != null && category.isNotEmpty;

    if (!hasSearch && !hasCategory) {
      final rows = await _client
          .from('restaurants')
          .select('id, name, description, logo_url');
      return rows.map(Restaurant.fromMap).toList();
    }

    var builder = _client
        .from('restaurants')
        .select(
          hasCategory
              ? 'id, name, description, logo_url, menu_items!inner(categorie_id)'
              : 'id, name, description, logo_url',
        );

    if (hasCategory) {
      builder = builder.eq('menu_items.categorie_id', category);
    }
    if (hasSearch) {
      builder = builder.ilike('name', '%$query%');
    }

    final rows = await builder.order('name').limit(_filteredResultLimit);
    return rows.map(Restaurant.fromMap).toList();
  }
}
