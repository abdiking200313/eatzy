class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
  });

  final String id;
  final String name;
  final String description;
  final String logoUrl;

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Unknown',
      description: map['description'] as String? ?? '',
      logoUrl: map['logo_url'] as String? ?? '',
    );
  }

  /// Inverse of [Restaurant.fromMap], using the same column names.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'logo_url': logoUrl,
  };
}
