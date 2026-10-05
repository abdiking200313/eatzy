import 'package:supabase_flutter/supabase_flutter.dart';

import '../../store/models/merchant_vertical.dart';
import '../models/merchant_order.dart';
import '../models/merchant_order_vertical.dart';

/// Thrown when `advance_<vertical>_order_status` rejects a status change --
/// an illegal transition, an order the caller does not manage, or an order
/// that no longer exists (see
/// `supabase/migrations/20260830140000_add_order_status_transition_rpcs.sql`).
/// [message] is the RPC's own `raise exception` text, which is already
/// specific and human-readable (e.g. "Illegal food order status transition:
/// confirmed -> out_for_delivery"), so it is surfaced to the merchant
/// verbatim rather than replaced with a generic message -- issue #134
/// requires an illegal transition to produce a clear error, not a silent
/// no-op.
class OrderStatusTransitionException implements Exception {
  const OrderStatusTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Data access for the signed-in merchant's own orders (ported from
/// `merchant_app`, originally issue #134, unified into the main app by
/// issue #232): `food_orders` / `grocery_orders` / `pharmacy_orders`, scoped
/// to the caller's own store via the select policies added in
/// `supabase/migrations/20260920000000_add_merchant_order_read_policies.sql`,
/// and status changes driven exclusively through the `advance_*_order_status`
/// RPCs from issue #131 -- no direct table writes, per the issue.
abstract interface class MerchantOrdersRepository {
  /// Fetches every order belonging to [storeId] in [vertical], newest
  /// first, each with its line items.
  Future<List<MerchantOrder>> fetchOrders({
    required MerchantVertical vertical,
    required String storeId,
  });

  /// Calls `advance_<vertical>_order_status(p_order_id, p_new_status)` for
  /// [orderId], returning the new status on success. Throws
  /// [OrderStatusTransitionException] if the server rejects the transition.
  Future<String> advanceOrderStatus({
    required MerchantVertical vertical,
    required String orderId,
    required String newStatus,
  });
}

class SupabaseMerchantOrdersRepository implements MerchantOrdersRepository {
  // `client` is deliberately a public-looking named parameter, matching
  // `SupabaseMerchantStoreRepository`/`SupabaseMerchantCatalogRepository`'s
  // existing convention.
  SupabaseMerchantOrdersRepository({required SupabaseClient client})
    // ignore: prefer_initializing_formals
    : _client = client;

  final SupabaseClient _client;

  /// Bound on a single store's own order read -- generous relative to any
  /// one store's realistic order volume, matching this app's existing
  /// `SupabaseMerchantCatalogRepository.maxItemsPerStore` convention.
  static const int maxOrdersPerStore = 500;

  List<String> _orderColumns(MerchantVertical vertical) => [
    'id',
    'status',
    'created_at',
    'subtotal',
    'delivery_fee',
    if (vertical.orderHasTax) 'tax',
    'total',
    'recipient_name',
    'phone',
    'street',
    'district',
    'city',
    if (vertical.orderHasDeliverySlot) ...[
      'delivery_slot_label',
      'substitution_preference',
    ],
    if (vertical.orderHasDeliveryInstructions) 'delivery_instructions',
    'payment_method',
    'payment_status',
  ];

  List<String> _itemColumns(MerchantVertical vertical) => [
    'id',
    vertical.orderItemNameColumn,
    'quantity',
    'unit_price',
  ];

  String _selection(MerchantVertical vertical) {
    final orderColumns = _orderColumns(vertical).join(', ');
    final itemColumns = _itemColumns(vertical).join(', ');
    return '$orderColumns, ${vertical.orderItemsTable}($itemColumns)';
  }

  @override
  Future<List<MerchantOrder>> fetchOrders({
    required MerchantVertical vertical,
    required String storeId,
  }) async {
    final storeColumn = vertical.orderStoreColumn;
    var query = _client.from(vertical.orderTable).select(_selection(vertical));
    // Pharmacy orders have no store column to filter on client-side at all
    // (see `merchant_order_vertical.dart`'s doc on `orderStoreColumn`) --
    // the merchant-scoped select policy from
    // `20260920000000_add_merchant_order_read_policies.sql` is the only
    // thing narrowing the result set for that vertical.
    if (storeColumn != null) {
      query = query.eq(storeColumn, storeId);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(maxOrdersPerStore);
    return List.unmodifiable(
      (rows as List).map(
        (row) => MerchantOrder.fromMap(
          row as Map<String, dynamic>,
          vertical: vertical,
        ),
      ),
    );
  }

  @override
  Future<String> advanceOrderStatus({
    required MerchantVertical vertical,
    required String orderId,
    required String newStatus,
  }) async {
    try {
      final result = await _client.rpc<Object?>(
        vertical.advanceOrderStatusRpc,
        params: {'p_order_id': orderId, 'p_new_status': newStatus},
      );
      return result as String? ?? newStatus;
    } on PostgrestException catch (error) {
      throw OrderStatusTransitionException(error.message);
    }
  }
}
