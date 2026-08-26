import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Default page size for the unbounded home-feed restaurant list.
  ///
  /// The home screen (`HomeScreen`) does not yet page through this list —
  /// see issue #61 — so this only bounds the worst case (every restaurant
  /// in the catalog fetched on every load). A real "load more"/infinite
  /// scroll contract for the home feed is left as a follow-up.
  static const int defaultPageSize = 50;

  /// Fetches restaurants, bounded to [limit] rows starting at [offset].
  Future<List<Restaurant>> fetchRestaurants({
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('restaurants')
        .select('id, name, description, logo_url')
        .order('name')
        .range(offset, offset + limit - 1);

    return rows.map(Restaurant.fromMap).toList();
  }
}
