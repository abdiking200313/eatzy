import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Default page size for restaurant queries below.
  ///
  /// The home screen (`HomeScreen`) does not yet page through the plain
  /// unfiltered listing — see issue #61 — so [limit]/[offset] here only
  /// bound the worst case (every restaurant in the catalog fetched on every
  /// load). A real "load more"/infinite scroll contract for the home feed
  /// is left as a follow-up.
  static const int defaultPageSize = 50;

  /// Fetches restaurants, optionally narrowed by a case-insensitive [name]
  /// substring match and/or restaurants that have at least one menu item in
  /// [categoryId] (an `item_categories.id`, joined via the existing
  /// `menu_items.categorie_id` relationship also used by
  /// `RestaurantMenuRepository`/`CategoryRepository`), bounded to [limit]
  /// rows starting at [offset].
  Future<List<Restaurant>> fetchRestaurants({
    String? searchQuery,
    String? categoryId,
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final query = searchQuery?.trim();
    final hasSearch = query != null && query.isNotEmpty;
    final category = categoryId;
    final hasCategory = category != null && category.isNotEmpty;

    if (!hasSearch && !hasCategory) {
      final rows = await _client
          .from('restaurants')
          .select('id, name, description, logo_url')
          .order('name')
          .range(offset, offset + limit - 1);
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

    final rows = await builder.order('name').range(offset, offset + limit - 1);
    return rows.map(Restaurant.fromMap).toList();
  }
}
