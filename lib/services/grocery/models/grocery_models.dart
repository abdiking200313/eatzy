enum GroceryPricingUnit { each, kilogram }

enum GroceryStockState { inStock, lowStock, outOfStock }

enum GrocerySubstitutionPreference { bestMatch, contactMe, noSubstitutions }

extension GrocerySubstitutionPreferenceLabel on GrocerySubstitutionPreference {
  String get label => switch (this) {
    GrocerySubstitutionPreference.bestMatch => 'Choose the best match',
    GrocerySubstitutionPreference.contactMe => 'Contact me first',
    GrocerySubstitutionPreference.noSubstitutions => 'No substitutions',
  };

  String get description => switch (this) {
    GrocerySubstitutionPreference.bestMatch =>
      'Replace unavailable items with a similar product.',
    GrocerySubstitutionPreference.contactMe =>
      'Ask before replacing an unavailable item.',
    GrocerySubstitutionPreference.noSubstitutions =>
      'Refund any item that becomes unavailable.',
  };
}

class GroceryStore {
  const GroceryStore({
    required this.id,
    required this.name,
    required this.area,
    required this.products,
  });

  final String id;
  final String name;
  final String area;
  final List<GroceryProduct> products;

  factory GroceryStore.fromMap(
    Map<String, dynamic> map, {
    required List<GroceryProduct> products,
  }) {
    return GroceryStore(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      area: _requiredString(map, 'area'),
      products: List.unmodifiable(products),
    );
  }
}

class GroceryProduct {
  const GroceryProduct({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.unitPrice,
    required this.pricingUnit,
    required this.stockState,
    required this.availableQuantity,
    required this.icon,
  });

  final String id;
  final String storeId;
  final String name;
  final String description;
  final double unitPrice;
  final GroceryPricingUnit pricingUnit;
  final GroceryStockState stockState;
  final double availableQuantity;
  final String icon;

  double get quantityStep => pricingUnit == GroceryPricingUnit.each ? 1 : 0.5;

  String get unitLabel =>
      pricingUnit == GroceryPricingUnit.each ? 'each' : 'per kg';

  bool get isAvailable =>
      stockState != GroceryStockState.outOfStock &&
      availableQuantity >= quantityStep;

  factory GroceryProduct.fromMap(Map<String, dynamic> map) {
    final pricingUnit = switch (_requiredString(map, 'pricing_unit')) {
      'each' => GroceryPricingUnit.each,
      'kilogram' => GroceryPricingUnit.kilogram,
      final value => throw FormatException(
        'Unsupported grocery pricing unit: $value',
      ),
    };
    final availableQuantity = _requiredDouble(map, 'available_quantity');
    final lowStockThreshold = _requiredDouble(map, 'low_stock_threshold');
    final quantityStep = _requiredDouble(map, 'quantity_step');
    final expectedStep = pricingUnit == GroceryPricingUnit.each ? 1.0 : 0.5;

    if (quantityStep != expectedStep) {
      throw FormatException(
        'Invalid quantity_step for ${pricingUnit.name}: $quantityStep',
      );
    }

    return GroceryProduct(
      id: _requiredString(map, 'id'),
      storeId: _requiredString(map, 'store_id'),
      name: _requiredString(map, 'name'),
      description: _optionalString(map, 'description'),
      unitPrice: _requiredNonNegativeDouble(map, 'unit_price'),
      pricingUnit: pricingUnit,
      stockState: availableQuantity <= 0
          ? GroceryStockState.outOfStock
          : availableQuantity <= lowStockThreshold
          ? GroceryStockState.lowStock
          : GroceryStockState.inStock,
      availableQuantity: availableQuantity,
      icon: _optionalString(map, 'icon', fallback: '🛒'),
    );
  }
}

class GroceryCartLine {
  const GroceryCartLine({required this.product, required this.quantity});

  final GroceryProduct product;
  final double quantity;

  double get total => product.unitPrice * quantity;

  GroceryCartLine copyWith({double? quantity}) {
    return GroceryCartLine(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class GroceryDeliverySlot {
  const GroceryDeliverySlot({
    required this.id,
    required this.label,
    required this.detail,
    this.storeId,
  });

  final String id;
  final String label;
  final String detail;
  final String? storeId;

  factory GroceryDeliverySlot.fromMap(Map<String, dynamic> map) {
    return GroceryDeliverySlot(
      id: _requiredString(map, 'id'),
      label: _requiredString(map, 'label'),
      detail: _requiredString(map, 'detail'),
      storeId: _requiredString(map, 'store_id'),
    );
  }
}

class GroceryDeliveryAddress {
  const GroceryDeliveryAddress({
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

class GroceryOrderConfirmation {
  const GroceryOrderConfirmation({
    required this.orderId,
    required this.createdAt,
    required this.amount,
    required this.slot,
    required this.address,
    required this.substitutionPreference,
  });

  final String orderId;
  final DateTime createdAt;
  final double amount;
  final GroceryDeliverySlot slot;
  final GroceryDeliveryAddress address;
  final GrocerySubstitutionPreference substitutionPreference;
}

class GroceryCheckoutResult {
  const GroceryCheckoutResult._({required this.errors, this.confirmation});

  factory GroceryCheckoutResult.invalid(List<String> errors) {
    return GroceryCheckoutResult._(errors: List.unmodifiable(errors));
  }

  factory GroceryCheckoutResult.confirmed(
    GroceryOrderConfirmation confirmation,
  ) {
    return GroceryCheckoutResult._(
      errors: const [],
      confirmation: confirmation,
    );
  }

  final List<String> errors;
  final GroceryOrderConfirmation? confirmation;

  bool get isSuccess => confirmation != null;
}

class GroceryOrderLineInput {
  const GroceryOrderLineInput({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final double quantity;

  Map<String, dynamic> toRpcMap() {
    if (productId.trim().isEmpty) {
      throw const FormatException('A grocery product ID is required.');
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw const FormatException('Grocery quantity must be positive.');
    }
    return {'product_id': productId, 'quantity': quantity};
  }
}

class GroceryOrderRequest {
  const GroceryOrderRequest({
    required this.storeId,
    required this.deliverySlotId,
    required this.address,
    required this.substitutionPreference,
    required this.items,
  });

  final String storeId;
  final String deliverySlotId;
  final GroceryDeliveryAddress address;
  final GrocerySubstitutionPreference substitutionPreference;
  final List<GroceryOrderLineInput> items;

  Map<String, dynamic> toRpcParams() {
    if (storeId.trim().isEmpty || deliverySlotId.trim().isEmpty) {
      throw const FormatException('Store and delivery slot are required.');
    }
    if (items.isEmpty) {
      throw const FormatException(
        'A grocery order requires at least one item.',
      );
    }

    return {
      'p_store_id': storeId,
      'p_delivery_slot_id': deliverySlotId,
      'p_recipient_name': address.recipientName.trim(),
      'p_phone': address.phone.trim(),
      'p_street': address.street.trim(),
      'p_district': address.district.trim(),
      'p_city': address.city.trim(),
      'p_substitution_preference': switch (substitutionPreference) {
        GrocerySubstitutionPreference.bestMatch => 'best_match',
        GrocerySubstitutionPreference.contactMe => 'contact_me',
        GrocerySubstitutionPreference.noSubstitutions => 'no_substitutions',
      },
      'p_items': items.map((item) => item.toRpcMap()).toList(growable: false),
    };
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required grocery field: $key');
  }
  return value;
}

String _optionalString(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final value = map[key]?.toString().trim();
  return value == null || value.isEmpty ? fallback : value;
}

double _requiredDouble(Map<String, dynamic> map, String key) {
  final value = map[key];
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('Invalid grocery number: $key');
  }
  return parsed;
}

double _requiredNonNegativeDouble(Map<String, dynamic> map, String key) {
  final value = _requiredDouble(map, key);
  if (value < 0) {
    throw FormatException('Grocery $key cannot be negative.');
  }
  return value;
}
