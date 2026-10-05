import '../../store/models/merchant_vertical.dart';

/// Per-vertical order table/column/RPC configuration (ported from
/// `merchant_app`, originally issue #134, unified into the main app by
/// issue #232), mirroring how `merchant_vertical.dart` (issue #133) captures
/// per-vertical store/catalog columns rather than forcing one fictitious
/// common shape.
///
/// Table/column names verified against the actual migrations, not guessed:
///   - `supabase/migrations/20260727152319_connect_super_app_services.sql`
///     (original `food_orders` / `grocery_orders` / `pharmacy_orders` /
///     `*_order_items` shapes).
///   - `supabase/migrations/20260826200000_add_food_order_delivery_address.sql`
///     (added `recipient_name`/`phone`/`street`/`district`/`city` to
///     `food_orders`, matching grocery's existing shape).
///   - `supabase/migrations/20260903000000_convert_money_columns_to_cents.sql`
///     (`subtotal`/`delivery_fee`/`tax`/`total`/`unit_price` are integer
///     cents on every order/order-item table).
///   - `supabase/migrations/20260913000000_add_order_payment_columns.sql`
///     (`payment_method`/`payment_status` on all three order tables).
///   - `supabase/migrations/20260917000000_add_shared_delivery_addresses.sql`
///     (renamed `pharmacy_orders.customer_name/phone_number/address_line` to
///     `recipient_name/phone/street`, so all three order tables now share
///     the SAME baseline contact/address column names -- no per-vertical
///     mapping needed for those).
///   - `supabase/migrations/20260830140000_add_order_status_transition_rpcs.sql`
///     (issue #131: the `advance_*_order_status` RPCs and the exact
///     per-vertical legal-transition vocabulary read off
///     `is_legal_order_status_transition`, not invented).
///   - `supabase/migrations/20260920000000_add_merchant_order_read_policies.sql`
///     (issue #134: the merchant-side select policies this feature's reads
///     depend on).
extension MerchantOrderVerticalConfig on MerchantVertical {
  /// The order table for this vertical.
  String get orderTable => switch (this) {
    MerchantVertical.food => 'food_orders',
    MerchantVertical.grocery => 'grocery_orders',
    MerchantVertical.pharmacy => 'pharmacy_orders',
  };

  /// The order line-item table for this vertical.
  String get orderItemsTable => switch (this) {
    MerchantVertical.food => 'food_order_items',
    MerchantVertical.grocery => 'grocery_order_items',
    MerchantVertical.pharmacy => 'pharmacy_order_items',
  };

  /// The foreign-key column on [orderTable] pointing at the owning store,
  /// or `null` for pharmacy -- `pharmacy_orders` has no store column at all
  /// (see #131's header: pharmacy ownership is derived through its items,
  /// not a direct FK). A pharmacy order list is therefore fetched relying
  /// on RLS alone (`public.merchant_owns_order`), with no client-side
  /// `.eq(...)` filter to add on top.
  String? get orderStoreColumn => switch (this) {
    MerchantVertical.food => 'restaurant_id',
    MerchantVertical.grocery => 'store_id',
    MerchantVertical.pharmacy => null,
  };

  /// The item-name column on [orderItemsTable].
  String get orderItemNameColumn => switch (this) {
    MerchantVertical.food => 'item_name',
    MerchantVertical.grocery => 'product_name',
    MerchantVertical.pharmacy => 'product_name',
  };

  /// The `advance_*_order_status(p_order_id uuid, p_new_status text)` RPC
  /// name for this vertical (issue #131).
  String get advanceOrderStatusRpc => switch (this) {
    MerchantVertical.food => 'advance_food_order_status',
    MerchantVertical.grocery => 'advance_grocery_order_status',
    MerchantVertical.pharmacy => 'advance_pharmacy_order_status',
  };

  /// Only `food_orders` has a `tax` column.
  bool get orderHasTax => this == MerchantVertical.food;

  /// Only `grocery_orders` has `delivery_slot_label` /
  /// `substitution_preference` columns.
  bool get orderHasDeliverySlot => this == MerchantVertical.grocery;

  /// Only `pharmacy_orders` has a `delivery_instructions` column.
  bool get orderHasDeliveryInstructions => this == MerchantVertical.pharmacy;

  /// The forward status vocabulary for this vertical, read directly off
  /// `is_legal_order_status_transition` in
  /// `20260830140000_add_order_status_transition_rpcs.sql` (excluding the
  /// `cancelled` branch, which is reachable from either of the first two
  /// states -- see [canCancelOrder]). Not invented: food is
  /// `confirmed -> preparing -> out_for_delivery -> delivered`, grocery
  /// swaps `preparing` for `shopping`, pharmacy swaps it for `packing`.
  List<String> get orderStatusFlow => switch (this) {
    MerchantVertical.food => const [
      'confirmed',
      'preparing',
      'out_for_delivery',
      'delivered',
    ],
    MerchantVertical.grocery => const [
      'confirmed',
      'shopping',
      'out_for_delivery',
      'delivered',
    ],
    MerchantVertical.pharmacy => const [
      'confirmed',
      'packing',
      'out_for_delivery',
      'delivered',
    ],
  };
}

/// Human-readable label for a raw order status value, shared across all
/// three verticals (the status vocabularies never collide on a shared
/// value with different meanings).
String merchantOrderStatusLabel(String status) => switch (status) {
  'confirmed' => 'Confirmed',
  'preparing' => 'Preparing',
  'shopping' => 'Shopping',
  'packing' => 'Packing',
  'out_for_delivery' => 'Out for delivery',
  'delivered' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => status,
};

/// The next forward status after [status] in [vertical]'s
/// [MerchantOrderVerticalConfig.orderStatusFlow], or `null` if [status] is
/// unrecognized or already the terminal (`delivered`) state. Used to drive
/// the single "advance" action on the order detail screen -- the RPC itself
/// is still the enforcement point (issue #134: "no direct table writes"),
/// this only decides what to *offer* the merchant next.
String? nextForwardOrderStatus(MerchantVertical vertical, String status) {
  final flow = vertical.orderStatusFlow;
  final index = flow.indexOf(status);
  if (index == -1 || index == flow.length - 1) return null;
  return flow[index + 1];
}

/// Whether [status] is one of the two states `is_legal_order_status_transition`
/// allows a `cancelled` transition from (the vertical's first two forward
/// states) -- see the RPC migration's comment: "Each vertical may
/// additionally go to 'cancelled' from either of its first two states."
bool canCancelOrder(MerchantVertical vertical, String status) {
  final flow = vertical.orderStatusFlow;
  final index = flow.indexOf(status);
  return index == 0 || index == 1;
}
