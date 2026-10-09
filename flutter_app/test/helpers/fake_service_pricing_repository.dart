import 'package:chowflow/services/shared/data/service_pricing_repository.dart';
import 'package:chowflow/services/shared/models/service_pricing.dart';

/// A [ServicePricingRepository] test double that never touches the network:
/// [peek] returns whatever was pre-seeded (or later set via [set]) and
/// [load] simply resolves to the same in-memory value, so controller tests
/// can exercise real pricing math without a live Supabase client.
class FakeServicePricingRepository implements ServicePricingRepository {
  FakeServicePricingRepository([Map<String, ServicePricing>? seed])
    : _pricing = {...?seed};

  final Map<String, ServicePricing> _pricing;

  /// Pre-seeded pricing for `'food'`: 499 cents delivery / 10% tax, the
  /// standard default so tests that don't care about pricing see
  /// consistent numbers.
  factory FakeServicePricingRepository.food({
    int deliveryFeeCents = 499,
    double taxRate = 0.10,
  }) => FakeServicePricingRepository({
    'food': ServicePricing(
      serviceId: 'food',
      deliveryFeeCents: deliveryFeeCents,
      taxRate: taxRate,
    ),
  });

  /// Pre-seeded pricing for `'grocery'`, matching the historical hardcoded
  /// `GroceryController.standardDeliveryFee` (250 cents, no tax).
  factory FakeServicePricingRepository.grocery({int deliveryFeeCents = 250}) =>
      FakeServicePricingRepository({
        'grocery': ServicePricing(
          serviceId: 'grocery',
          deliveryFeeCents: deliveryFeeCents,
          taxRate: 0,
        ),
      });

  /// Pre-seeded pricing for `'pharmacy'`, matching the historical hardcoded
  /// `PharmacyController.deliveryFee` (250 cents, no tax).
  factory FakeServicePricingRepository.pharmacy({int deliveryFeeCents = 250}) =>
      FakeServicePricingRepository({
        'pharmacy': ServicePricing(
          serviceId: 'pharmacy',
          deliveryFeeCents: deliveryFeeCents,
          taxRate: 0,
        ),
      });

  /// An empty repository: every [peek] returns `null`, simulating pricing
  /// that has never successfully loaded (e.g. first launch while offline).
  FakeServicePricingRepository.unconfigured() : _pricing = {};

  void set(String serviceId, ServicePricing pricing) {
    _pricing[serviceId] = pricing;
  }

  @override
  ServicePricing? peek(String serviceId) => _pricing[serviceId];

  @override
  Future<ServicePricing?> load(String serviceId) async => _pricing[serviceId];
}
