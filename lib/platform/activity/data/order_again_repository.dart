import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/service_module.dart';
import '../../../services/food/models/cart_item.dart';
import '../../../services/grocery/models/grocery_models.dart';
import '../../../services/pharmacy/models/pharmacy_product.dart';

/// A past order's lines matched against today's catalog, ready to put back
/// into the right cart. Prices are today's, not the ones paid then.
sealed class ReorderBasket {
  const ReorderBasket({required this.skippedNames});

  /// Items from the past order that can't be ordered any more (removed,
  /// out of stock, or the store is closed).
  final List<String> skippedNames;

  bool get isEmpty;
}

class FoodReorderBasket extends ReorderBasket {
  const FoodReorderBasket({required this.items, required super.skippedNames});

  /// Each [CartItem] carries its quantity.
  final List<CartItem> items;

  @override
  bool get isEmpty => items.isEmpty;
}

class GroceryReorderBasket extends ReorderBasket {
  const GroceryReorderBasket({
    required this.lines,
    required super.skippedNames,
  });

  /// Quantities are already capped at today's available stock.
  final List<({GroceryProduct product, double quantity})> lines;

  @override
  bool get isEmpty => lines.isEmpty;
}

class PharmacyReorderBasket extends ReorderBasket {
  const PharmacyReorderBasket({
    required this.lines,
    required super.skippedNames,
  });

  /// Quantities are already capped at today's stock.
  final List<({PharmacyProduct product, int quantity})> lines;

  @override
  bool get isEmpty => lines.isEmpty;
}

abstract interface class OrderAgainRepository {
  /// Loads [orderId]'s lines (the caller's own order — RLS scopes it) and
  /// matches them against today's catalog. Returns `null` when the order
  /// can't be found.
  Future<ReorderBasket?> loadBasket({
    required ServiceId serviceId,
    required String orderId,
  });
}

class SupabaseOrderAgainRepository implements OrderAgainRepository {
  const SupabaseOrderAgainRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<ReorderBasket?> loadBasket({
    required ServiceId serviceId,
    required String orderId,
  }) => switch (serviceId) {
    ServiceId.food => _foodBasket(orderId),
    ServiceId.grocery => _groceryBasket(orderId),
    ServiceId.pharmacy => _pharmacyBasket(orderId),
    ServiceId.unknown => Future.value(null),
  };

  Future<ReorderBasket?> _foodBasket(String orderId) async {
    final order = await _client
        .from('food_orders')
        .select(
          'restaurant_id, restaurant_name, '
          'food_order_items(menu_item_id, item_name, quantity)',
        )
        .eq('id', orderId)
        .maybeSingle();
    if (order == null) return null;

    final pastLines = _rows(order['food_order_items']);
    final ids = [
      for (final line in pastLines)
        if (line['menu_item_id'] case final String id) id,
    ];
    final menuRows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('menu_items')
                .select('id, name, price, image_url, restaurant_id')
                .inFilter('id', ids)
                .eq('is_available', true),
          );
    final menuById = {for (final row in menuRows) row['id'].toString(): row};
    final restaurantOpen = await _client
        .from('restaurants')
        .select('id')
        .eq('id', order['restaurant_id'].toString())
        .eq('is_open', true)
        .maybeSingle();

    final items = <CartItem>[];
    final skipped = <String>[];
    for (final line in pastLines) {
      final menuRow = menuById[line['menu_item_id']?.toString()];
      final price = menuRow?['price'];
      if (restaurantOpen == null || menuRow == null || price is! num) {
        skipped.add(line['item_name'].toString());
        continue;
      }
      items.add(
        CartItem(
          menuItemId: menuRow['id'].toString(),
          restaurantId: order['restaurant_id'].toString(),
          restaurantName: order['restaurant_name'].toString(),
          name: menuRow['name'].toString(),
          unitPrice: price.round(),
          imageUrl: menuRow['image_url']?.toString() ?? '',
          quantity: (line['quantity'] as num).toInt().clamp(1, 99),
        ),
      );
    }
    return FoodReorderBasket(items: items, skippedNames: skipped);
  }

  Future<ReorderBasket?> _groceryBasket(String orderId) async {
    final order = await _client
        .from('grocery_orders')
        .select(
          'store_id, grocery_order_items(product_id, product_name, quantity)',
        )
        .eq('id', orderId)
        .maybeSingle();
    if (order == null) return null;

    final pastLines = _rows(order['grocery_order_items']);
    final ids = [
      for (final line in pastLines)
        if (line['product_id'] case final String id) id,
    ];
    final productRows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('grocery_products')
                .select(
                  'id, store_id, name, description, unit_price, '
                  'pricing_unit, quantity_step, available_quantity, '
                  'low_stock_threshold, icon, image_url, '
                  'grocery_categories(name, sort_order)',
                )
                .inFilter('id', ids)
                .eq('is_active', true),
          );
    final storeActive = await _client
        .from('grocery_stores')
        .select('id')
        .eq('id', order['store_id'].toString())
        .eq('is_active', true)
        .maybeSingle();
    final productsById = <String, GroceryProduct>{};
    for (final row in productRows) {
      final product = GroceryProduct.fromMap(row);
      productsById[product.id] = product;
    }

    final lines = <({GroceryProduct product, double quantity})>[];
    final skipped = <String>[];
    for (final line in pastLines) {
      final product = productsById[line['product_id']?.toString()];
      if (storeActive == null || product == null || !product.isAvailable) {
        skipped.add(line['product_name'].toString());
        continue;
      }
      final wanted = (line['quantity'] as num).toDouble();
      lines.add((
        product: product,
        quantity: wanted > product.availableQuantity
            ? product.availableQuantity
            : wanted,
      ));
    }
    return GroceryReorderBasket(lines: lines, skippedNames: skipped);
  }

  Future<ReorderBasket?> _pharmacyBasket(String orderId) async {
    final order = await _client
        .from('pharmacy_orders')
        .select('pharmacy_order_items(product_id, product_name, quantity)')
        .eq('id', orderId)
        .maybeSingle();
    if (order == null) return null;

    final pastLines = _rows(order['pharmacy_order_items']);
    final ids = [
      for (final line in pastLines)
        if (line['product_id'] case final String id) id,
    ];
    final productRows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('pharmacy_products')
                .select(
                  'id, name, description, unit_price, stock_quantity, '
                  'sale_type, image_url, store_id, '
                  'pharmacy_categories!inner(id, name)',
                )
                .inFilter('id', ids)
                .eq('is_active', true)
                .eq('sale_type', 'otc'),
          );
    final productsById = <String, PharmacyProduct>{};
    for (final row in productRows) {
      final product = PharmacyProduct.fromMap(row);
      productsById[product.id] = product;
    }

    final lines = <({PharmacyProduct product, int quantity})>[];
    final skipped = <String>[];
    for (final line in pastLines) {
      final product = productsById[line['product_id']?.toString()];
      if (product == null ||
          !product.isOverTheCounter ||
          !product.isAvailable) {
        skipped.add(line['product_name'].toString());
        continue;
      }
      final wanted = (line['quantity'] as num).toInt();
      lines.add((
        product: product,
        quantity: wanted.clamp(1, product.stockQuantity),
      ));
    }
    return PharmacyReorderBasket(lines: lines, skippedNames: skipped);
  }

  static List<Map<String, dynamic>> _rows(Object? value) => [
    if (value is List)
      for (final row in value)
        if (row is Map) Map<String, dynamic>.from(row),
  ];
}
