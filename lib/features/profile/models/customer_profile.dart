class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.avatarUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String? avatarUrl;

  String get displayName {
    final name = [firstName, lastName].join(' ').trim();
    return name.isEmpty ? 'Zivo customer' : name;
  }

  factory CustomerProfile.fromMap(Map<String, dynamic> map) {
    return CustomerProfile(
      id: _requiredString(map, 'id'),
      firstName: _optionalString(map, 'firstname') ?? '',
      lastName: _optionalString(map, 'lastname') ?? '',
      phone: _optionalString(map, 'phone') ?? '',
      avatarUrl: _optionalString(map, 'avatar_url'),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required profile field: $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}
