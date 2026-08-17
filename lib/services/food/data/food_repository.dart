import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/data/rpc_helpers.dart';
import '../models/food_models.dart';

abstract interface class FoodDealRepository {
  Future<List<FoodDeal>> fetchDeals({
    String? restaurantId,
    DateTime? availableAt,
  });
}

abstract interface class RestaurantLocationRepository {
  Future<List<RestaurantLocation>> fetchLocations(String restaurantId);
}

abstract interface class FoodOrderRepository {
  Future<String> placeOrder(FoodOrderRequest request);
}

class SupabaseFoodDealRepository implements FoodDealRepository {
  const SupabaseFoodDealRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  static const _selection =
      'id, restaurant_id, name, description, deal_price, image_url, '
      'starts_at, ends_at, restaurants!inner(name), '
      'deal_items(quantity, menu_items!inner(id, name, price, image_url))';

  @override
  Future<List<FoodDeal>> fetchDeals({
    String? restaurantId,
    DateTime? availableAt,
  }) async {
    final rows = restaurantId == null
        ? await _client
              .from('deals')
              .select(_selection)
              .eq('is_active', true)
              .order('created_at', ascending: false)
        : await _client
              .from('deals')
              .select(_selection)
              .eq('is_active', true)
              .eq('restaurant_id', restaurantId)
              .order('created_at', ascending: false);

    final moment = availableAt ?? DateTime.now();
    return List.unmodifiable(
      rows
          .map((row) => FoodDeal.fromMap(Map<String, dynamic>.from(row)))
          .where((deal) => deal.isAvailableAt(moment)),
    );
  }
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
  Future<String> placeOrder(FoodOrderRequest request) async {
    final response = await _client.rpc(
      'place_food_order',
      params: request.toRpcParams(),
    );
    return requiredRpcId(response, 'food order');
  }
}
