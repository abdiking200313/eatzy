import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/cache/query_cache.dart';
import '../models/service_pricing.dart';

/// Reads `public.service_pricing` (the single source of truth for
/// delivery-fee/tax values) for one vertical at a time — the shared backing
/// for every vertical's pre-checkout cart/checkout fee/tax estimate,
/// rather than a hardcoded Dart constant per vertical
/// (`CartController.taxRate`/`standardDeliveryFee`,
/// `GroceryController.standardDeliveryFee`, `PharmacyController.deliveryFee`).
///
/// [peek] never touches the network — it only reports what has already been
/// loaded (this session, or hydrated from disk via [QueryCache] on a cold
/// start). A cart/checkout screen that has never seen a successful load
/// (e.g. first launch while offline) gets `null` back and must show a
/// "Calculated at checkout" fallback rather than a fabricated/guessed
/// number — the `place_*_order` RPC remains the authoritative charge
/// regardless of what the client estimate shows, so this is never on the
/// critical path for placing an order.
abstract class ServicePricingRepository {
  /// The most recently loaded pricing for [serviceId] (`'food'`, `'grocery'`,
  /// or `'pharmacy'`), or `null` if nothing has loaded successfully yet.
  ServicePricing? peek(String serviceId);

  /// Loads (or refreshes) pricing for [serviceId]. Returns the freshly
  /// loaded value, or the last known value if this attempt failed, or `null`
  /// if nothing has ever loaded successfully. Never throws.
  Future<ServicePricing?> load(String serviceId);
}

/// The production [ServicePricingRepository], backed by Supabase and cached
/// with the existing stale-while-revalidate [QueryCache]/[CachedQuery]
/// pattern (see `lib/platform/cache/catalog_queries.dart` for the same
/// pattern applied to catalog reads).
class SupabaseServicePricingRepository implements ServicePricingRepository {
  SupabaseServicePricingRepository({SupabaseClient? client, QueryCache? cache})
    : _client = client,
      _cache = cache ?? QueryCache.instance;

  /// Resolved lazily inside [CachedQuery.load], never in a constructor or
  /// field initializer, so building this repository never requires
  /// `Supabase.instance` to already be initialized — mirrors
  /// `CatalogQueries`' "repositories are constructed inside `load`, never
  /// eagerly" rule.
  final SupabaseClient? _client;
  final QueryCache _cache;

  /// How long a cached price is shown without a background refresh. Pricing
  /// changes rarely enough that a whole hour of staleness within a session
  /// is an acceptable trade-off for not re-querying on every cart visit; a
  /// long-lived session still eventually picks up an owner-made change, and
  /// the order RPC is authoritative regardless.
  static const _maxAge = Duration(hours: 1);

  CachedQuery<ServicePricing> _query(String serviceId) => CachedQuery(
    key: 'service_pricing:$serviceId',
    maxAge: _maxAge,
    cache: _cache,
    load: () async {
      final client = _client ?? Supabase.instance.client;
      final row = await client
          .from('service_pricing')
          .select('service_id, delivery_fee_cents, tax_rate')
          .eq('service_id', serviceId)
          .single();
      return ServicePricing.fromMap(Map<String, dynamic>.from(row));
    },
    encode: (pricing) => pricing.toMap(),
    decode: (json) =>
        ServicePricing.fromMap(Map<String, dynamic>.from(json as Map)),
  );

  @override
  ServicePricing? peek(String serviceId) => _query(serviceId).peek();

  @override
  Future<ServicePricing?> load(String serviceId) async {
    final query = _query(serviceId);
    try {
      return await query.refresh();
    } on Object {
      // Best-effort: fall back to whatever was already cached (possibly
      // nothing), matching `CachedQuery.prefetch`'s "never throws" contract.
      return query.peek();
    }
  }
}
