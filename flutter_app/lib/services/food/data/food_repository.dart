import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/data/rpc_helpers.dart';
import '../models/food_models.dart';

abstract interface class RestaurantLocationRepository {
  Future<List<RestaurantLocation>> fetchLocations(String restaurantId);
}

abstract interface class FoodOrderRepository {
  Future<PlacedOrder> placeOrder(FoodOrderRequest request);
}

class SupabaseRestaurantLocationRepository
    implements RestaurantLocationRepository {
  const SupabaseRestaurantLocationRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<RestaurantLocation>> fetchLocations(String restaurantId) async {
    if (restaurantId.trim().isEmpty) {
      throw const FormatException('A restaurant ID is required.');
    }
    final rows = await _client
        .from('restaurant_locations')
        .select(
          'id, restaurant_id, store_name, phonenumber, latitude, longitude, '
          'mapcode, mapcode_territory',
        )
        .eq('restaurant_id', restaurantId)
        .order('store_name');

    return List.unmodifiable(
      rows.map(
        (row) => RestaurantLocation.fromMap(Map<String, dynamic>.from(row)),
      ),
    );
  }
}

class SupabaseFoodOrderRepository implements FoodOrderRepository {
  const SupabaseFoodOrderRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<PlacedOrder> placeOrder(FoodOrderRequest request) async {
    final response = await _client.rpc<Object?>(
      'place_food_order',
      params: request.toRpcParams(),
    );
    return PlacedOrder.fromRpcResponse(response, 'food order');
  }
}
