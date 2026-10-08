/// A vertical's delivery fee and tax rate, mirroring one row of the
/// `public.service_pricing` table — the single source of truth for fees/tax
/// since issue #60 (see
/// `supabase/migrations/20260915000000_add_service_pricing_config.sql`).
///
/// Issue #279: pre-checkout cart/checkout estimates in
/// `CartController`/`GroceryController`/`PharmacyController` read this
/// instead of duplicating it as a hardcoded Dart constant, so an owner
/// changing a `service_pricing` row is reflected in the estimate shown
/// before the order is even placed. The `place_*_order` RPC remains the
/// authoritative charge regardless of what this estimate shows.
class ServicePricing {
  const ServicePricing({
    required this.serviceId,
    required this.deliveryFeeCents,
    required this.taxRate,
  });

  /// `'food'`, `'grocery'`, or `'pharmacy'` — matches
  /// `service_pricing.service_id`.
  final String serviceId;

  /// In integer cents — see issue #8.
  final int deliveryFeeCents;

  /// A fraction (0.10 = 10%), not a percentage. `0` for a vertical that
  /// charges no tax (grocery, pharmacy).
  final double taxRate;

  Map<String, dynamic> toMap() => {
    'service_id': serviceId,
    'delivery_fee_cents': deliveryFeeCents,
    'tax_rate': taxRate,
  };

  factory ServicePricing.fromMap(Map<String, dynamic> map) => ServicePricing(
    serviceId: map['service_id'] as String,
    deliveryFeeCents: (map['delivery_fee_cents'] as num).round(),
    taxRate: (map['tax_rate'] as num).toDouble(),
  );
}
