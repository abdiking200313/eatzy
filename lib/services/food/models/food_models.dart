import '../../shared/models/delivery_details.dart';

class FoodOrderLineInput {
  const FoodOrderLineInput({required this.menuItemId, required this.quantity});

  final String menuItemId;
  final int quantity;

  Map<String, dynamic> toRpcMap() {
    if (menuItemId.trim().isEmpty) {
      throw const FormatException('A menu item ID is required.');
    }
    if (quantity <= 0) {
      throw const FormatException('Food quantity must be positive.');
    }
    return {'menu_item_id': menuItemId, 'quantity': quantity};
  }
}

class FoodOrderRequest {
  const FoodOrderRequest({
    required this.restaurantId,
    required this.items,
    this.delivery = const DeliveryDetails(),
    this.idempotencyKey,
  });

  final String restaurantId;
  final DeliveryDetails delivery;
  final List<FoodOrderLineInput> items;

  /// A client-generated token identifying this checkout attempt (issue
  /// #59). `place_food_order` uses it, together with the caller's profile,
  /// to return the existing order instead of inserting a duplicate when the
  /// same attempt is submitted more than once (a double-tap or a retry
  /// after a lost response). `null` disables that protection for this call.
  final String? idempotencyKey;

  Map<String, dynamic> toRpcParams() {
    if (restaurantId.trim().isEmpty) {
      throw const FormatException('A restaurant ID is required.');
    }
    if (items.isEmpty) {
      throw const FormatException('A food order requires at least one item.');
    }
    return {
      'p_restaurant_id': restaurantId,
      ...delivery.toRpcParams(),
      'p_items': items.map((item) => item.toRpcMap()).toList(growable: false),
      'p_idempotency_key': idempotencyKey,
    };
  }
}

class RestaurantLocation {
  const RestaurantLocation({
    required this.id,
    required this.restaurantId,
    required this.storeName,
    this.phoneNumber,
    this.latitude,
    this.longitude,
    this.mapcode,
    this.mapcodeTerritory,
  });

  final String id;
  final String restaurantId;
  final String storeName;
  final String? phoneNumber;
  final double? latitude;
  final double? longitude;
  final String? mapcode;
  final String? mapcodeTerritory;

  factory RestaurantLocation.fromMap(Map<String, dynamic> map) {
    return RestaurantLocation(
      id: _requiredString(map, 'id'),
      restaurantId: _requiredString(map, 'restaurant_id'),
      storeName: _requiredString(map, 'store_name'),
      phoneNumber: _optionalString(map, 'phonenumber'),
      latitude: _optionalDouble(map, 'latitude'),
      longitude: _optionalDouble(map, 'longitude'),
      mapcode: _optionalString(map, 'mapcode'),
      mapcodeTerritory: _optionalString(map, 'mapcode_territory'),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required food field: $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

double? _optionalDouble(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('Invalid food number: $key');
  }
  return parsed;
}
