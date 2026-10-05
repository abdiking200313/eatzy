import '../../store/models/merchant_vertical.dart';

/// Pricing unit for a grocery product -- mirrors
/// `grocery_products.pricing_unit`'s check constraint (`'each'` or
/// `'kilogram'`), and the tied `quantity_step` (`1` for `each`, `0.5` for
/// `kilogram`) from
/// `supabase/migrations/20260727152319_connect_super_app_services.sql`.
enum GroceryPricingUnit {
  each,
  kilogram;

  String get columnValue => switch (this) {
    GroceryPricingUnit.each => 'each',
    GroceryPricingUnit.kilogram => 'kilogram',
  };

  /// The `quantity_step` value the table's check constraint requires for
  /// this pricing unit.
  double get requiredQuantityStep => switch (this) {
    GroceryPricingUnit.each => 1,
    GroceryPricingUnit.kilogram => 0.5,
  };

  String get label => switch (this) {
    GroceryPricingUnit.each => 'Each',
    GroceryPricingUnit.kilogram => 'Per kilogram',
  };

  static GroceryPricingUnit fromColumnValue(String value) => switch (value) {
    'kilogram' => GroceryPricingUnit.kilogram,
    _ => GroceryPricingUnit.each,
  };
}

/// One row from whichever catalog-item table [vertical] maps to
/// (`menu_items` / `grocery_products` / `pharmacy_products`). Fields that
/// only exist on some verticals' tables are `null` on the others -- see
/// `merchant_vertical.dart` for the exact column mapping. Ported from
/// `merchant_app` (originally issue #133, unified into the main app by
/// issue #232).
class MerchantCatalogItem {
  const MerchantCatalogItem({
    required this.id,
    required this.storeId,
    required this.vertical,
    required this.name,
    required this.priceCents,
    required this.isAvailable,
    this.description,
    this.imageUrl,
    this.pricingUnit,
    this.availableQuantity,
    this.categoryId,
    this.stockQuantity,
  });

  final String id;
  final String storeId;
  final MerchantVertical vertical;
  final String name;
  final String? description;

  /// Integer cents -- see `merchant_vertical.dart`'s `itemPriceColumn` doc.
  final int priceCents;

  final bool isAvailable;

  /// `image_url` on every vertical's item table.
  final String? imageUrl;

  /// `grocery_products.pricing_unit` only.
  final GroceryPricingUnit? pricingUnit;

  /// `grocery_products.available_quantity` only.
  final double? availableQuantity;

  /// `pharmacy_products.category_id` only (a required foreign key to
  /// `pharmacy_categories`).
  final String? categoryId;

  /// `pharmacy_products.stock_quantity` only.
  final int? stockQuantity;

  factory MerchantCatalogItem.fromMap(
    Map<String, dynamic> map, {
    required MerchantVertical vertical,
    required String storeId,
  }) {
    return MerchantCatalogItem(
      id: map['id'] as String,
      storeId: storeId,
      vertical: vertical,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      priceCents: (map[vertical.itemPriceColumn] as num?)?.round() ?? 0,
      isAvailable: map[vertical.itemAvailableColumn] as bool? ?? false,
      imageUrl: map['image_url'] as String?,
      pricingUnit: vertical == MerchantVertical.grocery
          ? GroceryPricingUnit.fromColumnValue(
              map['pricing_unit'] as String? ?? 'each',
            )
          : null,
      availableQuantity: vertical == MerchantVertical.grocery
          ? (map['available_quantity'] as num?)?.toDouble()
          : null,
      categoryId: vertical == MerchantVertical.pharmacy
          ? map['category_id'] as String?
          : null,
      stockQuantity: vertical == MerchantVertical.pharmacy
          ? (map['stock_quantity'] as num?)?.round()
          : null,
    );
  }
}

/// A `pharmacy_categories` row, needed to populate the category picker when
/// a merchant adds/edits a pharmacy product -- `pharmacy_products.category_id`
/// is a required (`not null`) foreign key to this table, so unlike the other
/// two verticals a pharmacy product can't be created without picking one.
class PharmacyCategory {
  const PharmacyCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory PharmacyCategory.fromMap(Map<String, dynamic> map) =>
      PharmacyCategory(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
      );
}
