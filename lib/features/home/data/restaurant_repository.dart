import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Restaurant>> fetchRestaurants() async {
    final rows = await _client
        .from('restaurants')
        .select('id, name, description, logo_url');

    return rows.map(Restaurant.fromMap).toList();
  }
}
