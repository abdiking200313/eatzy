import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/slug_id.dart';
import '../../store/models/merchant_vertical.dart';
import '../models/merchant_catalog_item.dart';

/// Data access for the signed-in merchant's own catalog items (issue #133):
/// `menu_items` / `grocery_products` / `pharmacy_products`, scoped through
/// the parent store's `owner_id` per
/// `supabase/migrations/20260830130000_add_merchant_catalog_write_policies.sql`
/// ("ownership is inherited from the parent store" -- these item tables
/// have no `owner_id` column of their own).
abstract interface class MerchantCatalogRepository {
  /// Fetches every item belonging to [storeId] in [vertical], regardless of
  /// availability -- unlike the customer-facing catalog reads, a merchant
  /// managing their own catalog needs to see unavailable items too so they
  /// can re-enable them.
  Future<List<MerchantCatalogItem>> fetchItems({
    required MerchantVertical vertical,
    required String storeId,
  });

  Future<MerchantCatalogItem> createItem(MerchantCatalogItem draft);

  Future<MerchantCatalogItem> updateItem(MerchantCatalogItem item);

  Future<void> deleteItem({
    required MerchantVertical vertical,
    required String itemId,
  });

  Future<MerchantCatalogItem> setAvailability({
    required MerchantCatalogItem item,
    required bool isAvailable,
  });

  /// Active pharmacy categories, for the required category picker when
  /// adding/editing a pharmacy product. Public data (same "Public reads
  /// active..." policy shape every other catalog table has), so this is a
  /// plain read with no ownership scoping.
  Future<List<PharmacyCategory>> fetchPharmacyCategories();
}

class SupabaseMerchantCatalogRepository implements MerchantCatalogRepository {
  // `client` is deliberately a public-looking named parameter (used
  // cross-file, e.g. from `MerchantCatalogController.supabase`); an
  // initializing formal would force the external name to the private
  // `_client`, unusable outside this file.
  SupabaseMerchantCatalogRepository({required SupabaseClient client})
    // ignore: prefer_initializing_formals
    : _client = client;

  final SupabaseClient _client;

  /// Bound on a single store's own catalog read -- generous relative to any
  /// one store's realistic item count, matching the spirit of this repo's
  /// existing `SupabaseGroceryCatalogRepository.maxProductsPerStore`.
  static const int maxItemsPerStore = 500;

  List<String> _selectColumns(MerchantVertical vertical) => [
    'id',
    'name',
    'description',
    vertical.itemPriceColumn,
    vertical.itemAvailableColumn,
    if (vertical.itemSupportsImage) 'image_url',
    if (vertical == MerchantVertical.grocery) ...[
      'pricing_unit',
      'available_quantity',
    ],
    if (vertical == MerchantVertical.pharmacy) ...[
      'category_id',
      'stock_quantity',
    ],
  ];

  @override
  Future<List<MerchantCatalogItem>> fetchItems({
    required MerchantVertical vertical,
    required String storeId,
  }) async {
    final rows = await _client
        .from(vertical.itemTable)
        .select(_selectColumns(vertical).join(', '))
        .eq(vertical.itemStoreColumn, storeId)
        .order('name')
        .limit(maxItemsPerStore);
    return List.unmodifiable(
      (rows as List).map(
        (row) => MerchantCatalogItem.fromMap(
          row as Map<String, dynamic>,
          vertical: vertical,
          storeId: storeId,
        ),
      ),
    );
  }

  Map<String, dynamic> _writablePayload(MerchantCatalogItem item) {
    final vertical = item.vertical;
    final payload = <String, dynamic>{
      'name': item.name.trim(),
      'description': item.description?.trim() ?? '',
      vertical.itemPriceColumn: item.priceCents,
      vertical.itemAvailableColumn: item.isAvailable,
      if (vertical.itemSupportsImage) 'image_url': item.imageUrl?.trim(),
    };

    if (vertical == MerchantVertical.grocery) {
      final pricingUnit = item.pricingUnit ?? GroceryPricingUnit.each;
      payload['pricing_unit'] = pricingUnit.columnValue;
      // `quantity_step` has no default and its check constraint ties it
      // directly to `pricing_unit` (1 for each, 0.5 for kilogram), so both
      // are always written together to keep the row internally consistent.
      payload['quantity_step'] = pricingUnit.requiredQuantityStep;
      payload['available_quantity'] = item.availableQuantity ?? 0;
    }

    if (vertical == MerchantVertical.pharmacy) {
      final categoryId = item.categoryId;
      if (categoryId == null || categoryId.trim().isEmpty) {
        throw const FormatException('A pharmacy product needs a category.');
      }
      payload['category_id'] = categoryId;
      payload['stock_quantity'] = item.stockQuantity ?? 0;
      // `sale_type` is left unset: its check constraint
      // (`sale_type = 'otc'`) allows only one value, which the column's own
      // default already supplies -- there is nothing for this app to offer
      // a merchant a choice between.
    }

    return payload;
  }

  @override
  Future<MerchantCatalogItem> createItem(MerchantCatalogItem draft) async {
    final vertical = draft.vertical;
    if (draft.name.trim().isEmpty) {
      throw const FormatException('An item name is required.');
    }

    final payload = _writablePayload(draft)
      ..[vertical.itemStoreColumn] = draft.storeId;
    if (!vertical.itemIdIsServerGenerated) {
      payload['id'] = generateSlugId(draft.name);
    }

    final row = await _client
        .from(vertical.itemTable)
        .insert(payload)
        .select(_selectColumns(vertical).join(', '))
        .single();
    return MerchantCatalogItem.fromMap(
      row,
      vertical: vertical,
      storeId: draft.storeId,
    );
  }

  @override
  Future<MerchantCatalogItem> updateItem(MerchantCatalogItem item) async {
    if (item.name.trim().isEmpty) {
      throw const FormatException('An item name is required.');
    }

    final vertical = item.vertical;
    final row = await _client
        .from(vertical.itemTable)
        .update(_writablePayload(item))
        .eq('id', item.id)
        .select(_selectColumns(vertical).join(', '))
        .single();
    return MerchantCatalogItem.fromMap(
      row,
      vertical: vertical,
      storeId: item.storeId,
    );
  }

  @override
  Future<void> deleteItem({
    required MerchantVertical vertical,
    required String itemId,
  }) {
    return _client.from(vertical.itemTable).delete().eq('id', itemId);
  }

  @override
  Future<MerchantCatalogItem> setAvailability({
    required MerchantCatalogItem item,
    required bool isAvailable,
  }) async {
    final vertical = item.vertical;
    final row = await _client
        .from(vertical.itemTable)
        .update({vertical.itemAvailableColumn: isAvailable})
        .eq('id', item.id)
        .select(_selectColumns(vertical).join(', '))
        .single();
    return MerchantCatalogItem.fromMap(
      row,
      vertical: vertical,
      storeId: item.storeId,
    );
  }

  @override
  Future<List<PharmacyCategory>> fetchPharmacyCategories() async {
    final rows = await _client
        .from('pharmacy_categories')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return List.unmodifiable(
      (rows as List).map(
        (row) => PharmacyCategory.fromMap(row as Map<String, dynamic>),
      ),
    );
  }
}
