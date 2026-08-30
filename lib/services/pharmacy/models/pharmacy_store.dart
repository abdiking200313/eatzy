/// A single pharmacy a customer can order OTC products from
/// (`public.pharmacy_stores`, issue #129). The pharmacy vertical's
/// counterpart of `GroceryStore`/`Restaurant`.
class PharmacyStore {
  const PharmacyStore({
    required this.id,
    required this.name,
    required this.address,
  });

  final String id;
  final String name;
  final String address;

  factory PharmacyStore.fromMap(Map<String, dynamic> map) {
    return PharmacyStore(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      address: _optionalString(map, 'address'),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required pharmacy store field: $key');
  }
  return value;
}

String _optionalString(Map<String, dynamic> map, String key) {
  return map[key]?.toString().trim() ?? '';
}
