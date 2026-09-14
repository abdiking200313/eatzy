/// Shared helpers for unwrapping Supabase RPC responses.
///
/// These are used by the food, grocery, and pharmacy repositories, which
/// each call a `place_*_order` RPC. Issue #60 moved every fee/tax constant
/// into a single server-owned `service_pricing` config table (see
/// `supabase/migrations/20260915000000_add_service_pricing_config.sql`) and
/// changed all three RPCs from `returns uuid` to
/// `returns table(order_id uuid, subtotal integer, delivery_fee integer,
/// tax integer, total integer)`, so the client reads back the server's
/// authoritative pricing instead of only an id -- see [PlacedOrder].
library;

/// The authoritative pricing breakdown a `place_*_order` RPC returns for the
/// order it just placed -- or, on an idempotent retry (issue #59), the
/// matching existing order returned instead of a duplicate. All amounts are
/// integer cents (issue #8).
///
/// [tax] is always present for a uniform shape across verticals, even
/// though only food currently charges tax -- grocery and pharmacy always
/// return `0` (see the `service_pricing` seed data).
class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
  });

  final String orderId;

  /// In integer cents, computed server-side from live catalog prices.
  final int subtotal;

  /// In integer cents, read from `service_pricing` by the RPC.
  final int deliveryFee;

  /// In integer cents, read from `service_pricing` by the RPC. `0` for
  /// verticals that do not charge tax.
  final int tax;

  /// In integer cents: `subtotal + deliveryFee + tax`, as actually charged
  /// (and, since issue #60, actually returned) by the RPC -- this is the
  /// value that must be displayed/recorded post-order, never a
  /// client-computed cart total, which can be stale if a price changed
  /// between the cart being built and checkout being confirmed.
  final int total;

  /// Parses the single row a `place_*_order` RPC now returns.
  /// supabase_flutter/postgrest decodes a set-returning RPC call as a
  /// `List<dynamic>` of row maps; these RPCs always return exactly one row
  /// (the freshly-placed order, or the existing one on an idempotent
  /// retry), so the first element is used.
  ///
  /// [label] describes what the RPC was for (e.g. `'grocery order'`) and is
  /// used to build the [FormatException] message when [value] does not
  /// contain a usable row.
  factory PlacedOrder.fromRpcResponse(Object? value, String label) {
    if (value is! List || value.isEmpty) {
      throw FormatException('The $label RPC did not return a row.');
    }
    final row = value.first;
    if (row is! Map) {
      throw FormatException('The $label RPC returned an invalid row.');
    }
    final map = Map<String, dynamic>.from(row);
    return PlacedOrder(
      orderId: requiredRpcId(map['order_id'], label),
      subtotal: _requiredCents(map, 'subtotal', label),
      deliveryFee: _requiredCents(map, 'delivery_fee', label),
      tax: _requiredCents(map, 'tax', label),
      total: _requiredCents(map, 'total', label),
    );
  }
}

/// Extracts a required id from an RPC response [value], trimming whitespace
/// and validating it is non-empty.
///
/// [label] describes what the RPC was for (e.g. `'grocery order'`) and is
/// used to build the [FormatException] message when [value] does not
/// contain a usable id.
String requiredRpcId(Object? value, String label) {
  final id = value?.toString().trim();
  if (id == null || id.isEmpty) {
    throw FormatException('The $label RPC did not return an ID.');
  }
  return id;
}

int _requiredCents(Map<String, dynamic> map, String key, String label) {
  final value = map[key];
  final parsed = value is num
      ? value.round()
      : int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('The $label RPC row is missing $key.');
  }
  return parsed;
}
