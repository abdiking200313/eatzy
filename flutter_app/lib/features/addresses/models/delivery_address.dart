/// A saved delivery address, mapped from a `public.delivery_addresses` row
/// (issue #78 -- the shared platform table every vertical's order-placement
/// RPC can optionally resolve a fulfilment snapshot from, instead of each
/// vertical inventing its own address shape).
///
/// This is a *platform* model (`lib/features/addresses/**`), not a
/// service-specific one: it is intentionally distinct from
/// `FoodDeliveryAddress` / `GroceryDeliveryAddress` /
/// `PharmacyCheckoutDetails`, which are per-checkout, not-necessarily-saved
/// value objects a vertical's checkout screen builds from its own text
/// fields. Those three already share this exact recipient/phone/street/
/// district/city baseline (see `AGENTS.md`'s "Super-app architecture"
/// section) -- this class is the one persisted, reusable-across-verticals
/// record of it.
class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.district,
    required this.city,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.label,
  });

  final String id;

  /// e.g. "Home" / "Work". `null` when the address was saved without one.
  final String? label;
  final String recipientName;
  final String phone;
  final String street;
  final String district;
  final String city;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  static DeliveryAddress fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.tryParse(_requiredString(map, 'created_at'));
    if (createdAt == null) {
      throw const FormatException('Invalid delivery address creation time.');
    }
    final updatedAt = DateTime.tryParse(_requiredString(map, 'updated_at'));
    if (updatedAt == null) {
      throw const FormatException('Invalid delivery address update time.');
    }

    return DeliveryAddress(
      id: _requiredString(map, 'id'),
      label: _optionalString(map, 'label'),
      recipientName: _requiredString(map, 'recipient_name'),
      phone: _requiredString(map, 'phone'),
      street: _requiredString(map, 'street'),
      district: _requiredString(map, 'district'),
      city: _requiredString(map, 'city'),
      isDefault: map['is_default'] == true,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }
}

/// The fields a caller supplies to create or update a [DeliveryAddress].
/// `id`/`profile_id`/`created_at`/`updated_at` are server-managed and never
/// part of this input.
class NewDeliveryAddress {
  const NewDeliveryAddress({
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.district,
    required this.city,
    this.label,
    this.isDefault = false,
  });

  final String? label;
  final String recipientName;
  final String phone;
  final String street;
  final String district;
  final String city;
  final bool isDefault;

  Map<String, dynamic> toMap() {
    return {
      'label': label?.trim().isEmpty ?? true ? null : label!.trim(),
      'recipient_name': recipientName.trim(),
      'phone': phone.trim(),
      'street': street.trim(),
      'district': district.trim(),
      'city': city.trim(),
      'is_default': isDefault,
    };
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required delivery address field: $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}
