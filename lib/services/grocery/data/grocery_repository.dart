import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/data/rpc_helpers.dart';
import '../models/grocery_models.dart';

abstract interface class GroceryRepository {
  Future<List<GroceryStore>> fetchStores();
}

abstract interface class GroceryCatalogRepository {
  Future<List<GroceryStore>> fetchStores();

  /// Fetches a single store (`grocery_stores.id`) and just its own products,
  /// scoped by `grocery_products.store_id` — the grocery counterpart of
  /// `PharmacyCatalogRepository.fetchProducts(storeId: ...)`. Returns `null`
  /// when no active store matches [storeId]. Used by `GroceryStoreScreen`,
  /// which only ever renders one store at a time, instead of the
  /// every-store-at-once [fetchStores].
  Future<GroceryStore?> fetchStore(String storeId);

  Future<List<GroceryDeliverySlot>> fetchDeliverySlots(String storeId);
}

abstract interface class GroceryOrderRepository {
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request);
}

class SeededGroceryRepository implements GroceryRepository {
  const SeededGroceryRepository();

  @override
  Future<List<GroceryStore>> fetchStores() async => seededStores;

  static const List<GroceryStore> seededStores = [
    GroceryStore(
      id: 'bakaal-fresh',
      name: 'Bakaal Fresh',
      area: 'Hodan, Mogadishu',
      products: [
        GroceryProduct(
          id: 'bakaal-bananas',
          storeId: 'bakaal-fresh',
          name: 'Bananas',
          description: 'Fresh bananas, sold by weight',
          unitPrice: 180,
          pricingUnit: GroceryPricingUnit.kilogram,
          stockState: GroceryStockState.inStock,
          availableQuantity: 12,
          icon: '🍌',
        ),
        GroceryProduct(
          id: 'bakaal-rice',
          storeId: 'bakaal-fresh',
          name: 'Basmati rice',
          description: 'One 5 kg bag',
          unitPrice: 850,
          pricingUnit: GroceryPricingUnit.each,
          stockState: GroceryStockState.inStock,
          availableQuantity: 24,
          icon: '🍚',
        ),
        GroceryProduct(
          id: 'bakaal-milk',
          storeId: 'bakaal-fresh',
          name: 'Long-life milk',
          description: 'One litre carton',
          unitPrice: 125,
          pricingUnit: GroceryPricingUnit.each,
          stockState: GroceryStockState.lowStock,
          availableQuantity: 3,
          icon: '🥛',
        ),
        GroceryProduct(
          id: 'bakaal-tomatoes',
          storeId: 'bakaal-fresh',
          name: 'Tomatoes',
          description: 'Local tomatoes, sold by weight',
          unitPrice: 220,
          pricingUnit: GroceryPricingUnit.kilogram,
          stockState: GroceryStockState.outOfStock,
          availableQuantity: 0,
          icon: '🍅',
        ),
      ],
    ),
    GroceryStore(
      id: 'suuqa-hamar',
      name: 'Suuqa Hamar',
      area: 'Waberi, Mogadishu',
      products: [
        GroceryProduct(
          id: 'hamar-eggs',
          storeId: 'suuqa-hamar',
          name: 'Eggs',
          description: 'Tray of 12 eggs',
          unitPrice: 340,
          pricingUnit: GroceryPricingUnit.each,
          stockState: GroceryStockState.lowStock,
          availableQuantity: 4,
          icon: '🥚',
        ),
        GroceryProduct(
          id: 'hamar-potatoes',
          storeId: 'suuqa-hamar',
          name: 'Potatoes',
          description: 'Washed potatoes, sold by weight',
          unitPrice: 160,
          pricingUnit: GroceryPricingUnit.kilogram,
          stockState: GroceryStockState.inStock,
          availableQuantity: 18,
          icon: '🥔',
        ),
        GroceryProduct(
          id: 'hamar-detergent',
          storeId: 'suuqa-hamar',
          name: 'Laundry detergent',
          description: 'One 1 kg pack',
          unitPrice: 475,
          pricingUnit: GroceryPricingUnit.each,
          stockState: GroceryStockState.inStock,
          availableQuantity: 10,
          icon: '🧺',
        ),
      ],
    ),
  ];
}

class SupabaseGroceryCatalogRepository
    implements GroceryRepository, GroceryCatalogRepository {
  const SupabaseGroceryCatalogRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  /// Bounds on the multi-store browse read.
  ///
  /// `fetchStores()` renders every active store *and* its products
  /// together, grouping products by store client-side — used only by
  /// `GroceryScreen`'s store-*list* screen (store name/area/product count
  /// per card), not by the single-store `GroceryStoreScreen` (see
  /// [fetchStore], added by issue #177 once issue #140 introduced a
  /// "selected store" concept to scope by). These limits bound the worst
  /// case of that still-necessarily-multi-store read: previously this
  /// query had no limit at all and pulled the entire multi-store catalog
  /// on every load.
  static const int maxStores = 30;
  static const int maxProducts = 300;

  /// Bound on [fetchStore]'s single-store product read. Higher than
  /// [maxProducts] (which is spread across up to [maxStores] stores) since
  /// this is the full read for one store's own catalog.
  static const int maxProductsPerStore = 300;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    final results = await Future.wait<dynamic>([
      _client
          .from('grocery_stores')
          .select('id, name, area, image_url')
          .eq('is_active', true)
          .order('name')
          .limit(maxStores),
      _client
          .from('grocery_products')
          .select(
            'id, store_id, name, description, unit_price, pricing_unit, '
            'quantity_step, available_quantity, low_stock_threshold, icon',
          )
          .eq('is_active', true)
          .order('name')
          .limit(maxProducts),
    ]);

    final storeRows = _mapRows(results.first, 'grocery stores');
    final productRows = _mapRows(results.last, 'grocery products');
    final productsByStore = <String, List<GroceryProduct>>{};

    for (final row in productRows) {
      final product = GroceryProduct.fromMap(row);
      productsByStore.putIfAbsent(product.storeId, () => []).add(product);
    }

    return List.unmodifiable(
      storeRows.map(
        (row) => GroceryStore.fromMap(
          row,
          products: productsByStore[row['id']?.toString()] ?? const [],
        ),
      ),
    );
  }

  @override
  Future<GroceryStore?> fetchStore(String storeId) async {
    if (storeId.trim().isEmpty) {
      throw const FormatException('A grocery store ID is required.');
    }

    final storeRow = await _client
        .from('grocery_stores')
        .select('id, name, area, image_url')
        .eq('id', storeId)
        .eq('is_active', true)
        .maybeSingle();
    if (storeRow == null) {
      return null;
    }

    final productRows = await _client
        .from('grocery_products')
        .select(
          'id, store_id, name, description, unit_price, pricing_unit, '
          'quantity_step, available_quantity, low_stock_threshold, icon',
        )
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('name')
        .limit(maxProductsPerStore);

    final products = _mapRows(
      productRows,
      'grocery products',
    ).map(GroceryProduct.fromMap).toList(growable: false);

    return GroceryStore.fromMap(
      Map<String, dynamic>.from(storeRow),
      products: products,
    );
  }

  @override
  Future<List<GroceryDeliverySlot>> fetchDeliverySlots(String storeId) async {
    if (storeId.trim().isEmpty) {
      throw const FormatException('A grocery store ID is required.');
    }
    // Reads from `grocery_delivery_slots_available` (issue #82), not the
    // base `grocery_delivery_slots` table: the view already excludes a slot
    // whose computed delivery window has elapsed (and, via RLS with
    // `security_invoker`, an inactive slot or one at an inactive store), so
    // this query no longer needs its own `is_active` filter.
    final rows = await _client
        .from('grocery_delivery_slots_available')
        .select('id, store_id, label, detail')
        .eq('store_id', storeId)
        .order('sort_order');

    return List.unmodifiable(
      rows.map(
        (row) => GroceryDeliverySlot.fromMap(Map<String, dynamic>.from(row)),
      ),
    );
  }
}

class SupabaseGroceryOrderRepository implements GroceryOrderRepository {
  const SupabaseGroceryOrderRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<PlacedOrder> placeOrder(GroceryOrderRequest request) async {
    final response = await _client.rpc<Object?>(
      'place_grocery_order',
      params: request.toRpcParams(),
    );
    return PlacedOrder.fromRpcResponse(response, 'grocery order');
  }
}

List<Map<String, dynamic>> _mapRows(Object? value, String label) {
  if (value is! List) {
    throw FormatException('Expected a list of $label.');
  }
  return value
      .map((row) {
        if (row is! Map) {
          throw FormatException('Invalid $label row.');
        }
        return Map<String, dynamic>.from(row);
      })
      .toList(growable: false);
}
