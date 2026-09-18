import 'merchant_vertical.dart';

/// The signed-in merchant's own store row, from whichever vertical table it
/// actually lives in (ported from `merchant_app`, originally issue #133,
/// unified into the main app by issue #232). See `merchant_vertical.dart`
/// for the per-vertical column mapping this is built from.
class MerchantStore {
  const MerchantStore({
    required this.id,
    required this.vertical,
    required this.name,
    required this.location,
    required this.isOpen,
    this.description,
    this.imageUrl,
  });

  final String id;
  final MerchantVertical vertical;
  final String name;

  /// `restaurants.address` / `pharmacy_stores.address` / `grocery_stores.area`
  /// -- see [MerchantVerticalConfig.storeLocationColumn].
  final String location;

  /// `restaurants.is_open` / `grocery_stores.is_active` /
  /// `pharmacy_stores.is_active`.
  final bool isOpen;

  /// `restaurants.description`. `null` for grocery/pharmacy, which have no
  /// such column.
  final String? description;

  /// `restaurants.image_url`. `null` for grocery/pharmacy, which have no
  /// such column.
  final String? imageUrl;

  factory MerchantStore.fromMap(
    Map<String, dynamic> map, {
    required MerchantVertical vertical,
  }) {
    return MerchantStore(
      id: map['id'] as String,
      vertical: vertical,
      name: map['name'] as String? ?? '',
      location: map[vertical.storeLocationColumn] as String? ?? '',
      isOpen: map[vertical.storeActiveColumn] as bool? ?? false,
      description: vertical.storeSupportsDescription
          ? map['description'] as String?
          : null,
      imageUrl: vertical.storeSupportsImage
          ? map['image_url'] as String?
          : null,
    );
  }

  MerchantStore copyWith({
    String? name,
    String? location,
    bool? isOpen,
    String? description,
    String? imageUrl,
  }) {
    return MerchantStore(
      id: id,
      vertical: vertical,
      name: name ?? this.name,
      location: location ?? this.location,
      isOpen: isOpen ?? this.isOpen,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
