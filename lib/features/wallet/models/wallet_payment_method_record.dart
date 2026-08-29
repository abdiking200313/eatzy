/// Real payment method data, mapped from a `public.payment_methods` row.
///
/// This only carries display-safe fields (brand, last four digits, default
/// flag) — never `provider_payment_method_id`, which is a payment-provider
/// token, not something the wallet UI needs to render a card row.
class WalletPaymentMethodRecord {
  const WalletPaymentMethodRecord({
    required this.id,
    required this.brand,
    required this.lastFour,
    required this.isDefault,
  });

  final String id;
  final String brand;
  final String lastFour;
  final bool isDefault;

  static WalletPaymentMethodRecord fromMap(Map<String, dynamic> map) {
    return WalletPaymentMethodRecord(
      id: _requiredString(map, 'id'),
      brand: _requiredString(map, 'brand'),
      lastFour: _requiredString(map, 'last_four'),
      isDefault: map['is_default'] == true,
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required payment method field: $key');
  }
  return value;
}
