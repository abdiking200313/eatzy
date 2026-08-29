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

/// A real delivery address for a food order, matching the
/// recipient/phone/street/district/city shape already collected and
/// submitted by grocery (`GroceryDeliveryAddress`) and pharmacy
/// (`PharmacyCheckoutDetails`) checkout.
class FoodDeliveryAddress {
  const FoodDeliveryAddress({
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.district,
    required this.city,
    this.country = 'Somalia',
  });

  final String recipientName;
  final String phone;
  final String street;
  final String district;
  final String city;
  final String country;
}

class FoodOrderRequest {
  const FoodOrderRequest({
    required this.restaurantId,
    required this.address,
    required this.items,
  });

  final String restaurantId;
  final FoodDeliveryAddress address;
  final List<FoodOrderLineInput> items;

  Map<String, dynamic> toRpcParams() {
    if (restaurantId.trim().isEmpty) {
      throw const FormatException('A restaurant ID is required.');
    }
    if (items.isEmpty) {
      throw const FormatException('A food order requires at least one item.');
    }
    if (address.recipientName.trim().isEmpty ||
        address.phone.trim().isEmpty ||
        address.street.trim().isEmpty ||
        address.district.trim().isEmpty ||
        address.city.trim().isEmpty) {
      throw const FormatException(
        'Complete food delivery details are required.',
      );
    }
    return {
      'p_restaurant_id': restaurantId,
      'p_recipient_name': address.recipientName.trim(),
      'p_phone': address.phone.trim(),
      'p_street': address.street.trim(),
      'p_district': address.district.trim(),
      'p_city': address.city.trim(),
      'p_items': items.map((item) => item.toRpcMap()).toList(growable: false),
    };
  }
}

class FoodDealItem {
  const FoodDealItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  final String menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String? imageUrl;

  factory FoodDealItem.fromMap(Map<String, dynamic> map) {
    final menuValue = map['menu_items'];
    if (menuValue is! Map) {
      throw const FormatException('A deal item is missing its menu item.');
    }
    final menu = Map<String, dynamic>.from(menuValue);
    return FoodDealItem(
      menuItemId: _requiredString(menu, 'id'),
      name: _requiredString(menu, 'name'),
      quantity: _requiredPositiveInt(map, 'quantity'),
      unitPrice: _requiredNonNegativeDouble(menu, 'price'),
      imageUrl: _optionalString(menu, 'image_url'),
    );
  }
}

class FoodDeal {
  const FoodDeal({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.description,
    required this.dealPrice,
    required this.items,
    this.imageUrl,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String name;
  final String description;
  final double dealPrice;
  final String? imageUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<FoodDealItem> items;

  int get itemCount => items.fold(0, (count, item) => count + item.quantity);

  bool isAvailableAt(DateTime moment) {
    final utcMoment = moment.toUtc();
    return (startsAt == null || !utcMoment.isBefore(startsAt!)) &&
        (endsAt == null || utcMoment.isBefore(endsAt!));
  }

  factory FoodDeal.fromMap(Map<String, dynamic> map) {
    final restaurantValue = map['restaurants'];
    if (restaurantValue is! Map) {
      throw const FormatException('A deal is missing its restaurant.');
    }
    final itemValue = map['deal_items'];
    if (itemValue is! List) {
      throw const FormatException('A deal has invalid items.');
    }

    return FoodDeal(
      id: _requiredString(map, 'id'),
      restaurantId: _requiredString(map, 'restaurant_id'),
      restaurantName: _requiredString(
        Map<String, dynamic>.from(restaurantValue),
        'name',
      ),
      name: _requiredString(map, 'name'),
      description: _optionalString(map, 'description') ?? '',
      dealPrice: _requiredNonNegativeDouble(map, 'deal_price'),
      imageUrl: _optionalString(map, 'image_url'),
      startsAt: _optionalDateTime(map, 'starts_at'),
      endsAt: _optionalDateTime(map, 'ends_at'),
      items: List.unmodifiable(
        itemValue.map(
          (item) =>
              FoodDealItem.fromMap(Map<String, dynamic>.from(item as Map)),
        ),
      ),
    );
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

int _requiredPositiveInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    throw FormatException('Invalid positive food integer: $key');
  }
  return parsed;
}

double _requiredNonNegativeDouble(Map<String, dynamic> map, String key) {
  final value = _optionalDouble(map, key);
  if (value == null || value < 0) {
    throw FormatException('Invalid non-negative food number: $key');
  }
  return value;
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

DateTime? _optionalDateTime(Map<String, dynamic> map, String key) {
  final value = _optionalString(map, key);
  if (value == null) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid food timestamp: $key');
  }
  return parsed.toUtc();
}
