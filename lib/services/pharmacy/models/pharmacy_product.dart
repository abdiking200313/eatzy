enum PharmacySaleType { overTheCounter, prescriptionOnly, regulated }

class PharmacyProduct {
  const PharmacyProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.unitPrice,
    required this.stockQuantity,
    required this.saleType,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final double unitPrice;
  final int stockQuantity;
  final PharmacySaleType saleType;

  bool get isOverTheCounter => saleType == PharmacySaleType.overTheCounter;
  bool get isAvailable => stockQuantity > 0;
  bool get isLowStock => stockQuantity > 0 && stockQuantity <= 5;

  factory PharmacyProduct.fromMap(Map<String, dynamic> map) {
    final saleType = switch (_requiredString(map, 'sale_type')) {
      'otc' => PharmacySaleType.overTheCounter,
      'prescription_only' => PharmacySaleType.prescriptionOnly,
      'regulated' => PharmacySaleType.regulated,
      final value => throw FormatException(
        'Unsupported pharmacy sale type: $value',
      ),
    };
    final stockQuantity = _requiredInt(map, 'stock_quantity');
    final unitPrice = _requiredDouble(map, 'unit_price');
    if (stockQuantity < 0 || unitPrice < 0) {
      throw const FormatException(
        'Pharmacy stock and price cannot be negative.',
      );
    }

    final categoryValue = map['pharmacy_categories'];
    final categoryMap = categoryValue is Map
        ? Map<String, dynamic>.from(categoryValue)
        : null;

    return PharmacyProduct(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _optionalString(map, 'description'),
      category: categoryMap == null
          ? _requiredString(map, 'category_name')
          : _requiredString(categoryMap, 'name'),
      unitPrice: unitPrice,
      stockQuantity: stockQuantity,
      saleType: saleType,
    );
  }

  /// Serializes this product for local cart persistence. Distinct from
  /// [fromMap]/the Supabase row shape, since this snapshot is a flat,
  /// stable format meant only for round-tripping through local storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'unit_price': unitPrice,
      'stock_quantity': stockQuantity,
      'sale_type': saleType.name,
    };
  }

  factory PharmacyProduct.fromJson(Map<String, dynamic> json) {
    return PharmacyProduct(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      description: _optionalString(json, 'description'),
      category: _requiredString(json, 'category'),
      unitPrice: _requiredDouble(json, 'unit_price'),
      stockQuantity: _requiredInt(json, 'stock_quantity'),
      saleType: PharmacySaleType.values.byName(
        _requiredString(json, 'sale_type'),
      ),
    );
  }
}

class PharmacyCategory {
  const PharmacyCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory PharmacyCategory.fromMap(Map<String, dynamic> map) {
    return PharmacyCategory(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required pharmacy field: $key');
  }
  return value;
}

String _optionalString(Map<String, dynamic> map, String key) {
  return map[key]?.toString().trim() ?? '';
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Invalid pharmacy integer: $key');
  }
  return parsed;
}

double _requiredDouble(Map<String, dynamic> map, String key) {
  final value = map[key];
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('Invalid pharmacy number: $key');
  }
  return parsed;
}
