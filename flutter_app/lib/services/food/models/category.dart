class Category {
  const Category({required this.id, required this.name, required this.iconUrl});

  final String id;
  final String name;
  final String iconUrl;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Unknown',
      iconUrl: map['icon_url'] as String? ?? '',
    );
  }

  /// Inverse of [Category.fromMap], using the same column names.
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'icon_url': iconUrl};
}
