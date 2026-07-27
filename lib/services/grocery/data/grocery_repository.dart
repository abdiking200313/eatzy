import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/grocery_models.dart';

abstract interface class GroceryRepository {
  Future<List<GroceryStore>> fetchStores();
}

abstract interface class GroceryCatalogRepository {
  Future<List<GroceryStore>> fetchStores();

  Future<List<GroceryDeliverySlot>> fetchDeliverySlots(String storeId);
}

abstract interface class GroceryOrderRepository {
  Future<String> placeOrder(GroceryOrderRequest request);
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
          unitPrice: 1.80,
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
          unitPrice: 8.50,
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
          unitPrice: 1.25,
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
          unitPrice: 2.20,
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
          unitPrice: 3.40,
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
          unitPrice: 1.60,
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
          unitPrice: 4.75,
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

  @override
  Future<List<GroceryStore>> fetchStores() async {
    final results = await Future.wait<dynamic>([
      _client
          .from('grocery_stores')
          .select('id, name, area')
          .eq('is_active', true)
          .order('name'),
      _client
          .from('grocery_products')
          .select(
            'id, store_id, name, description, unit_price, pricing_unit, '
            'quantity_step, available_quantity, low_stock_threshold, icon',
          )
          .eq('is_active', true)
          .order('name'),
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
  Future<List<GroceryDeliverySlot>> fetchDeliverySlots(String storeId) async {
    if (storeId.trim().isEmpty) {
      throw const FormatException('A grocery store ID is required.');
    }
    final rows = await _client
        .from('grocery_delivery_slots')
        .select('id, store_id, label, detail')
        .eq('store_id', storeId)
        .eq('is_active', true)
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
  Future<String> placeOrder(GroceryOrderRequest request) async {
    final response = await _client.rpc(
      'place_grocery_order',
      params: request.toRpcParams(),
    );
    return _requiredRpcId(response, 'grocery order');
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

String _requiredRpcId(Object? value, String label) {
  final id = value?.toString().trim();
  if (id == null || id.isEmpty) {
    throw FormatException('The $label RPC did not return an ID.');
  }
  return id;
}
