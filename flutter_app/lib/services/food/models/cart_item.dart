class CartItem {
  const CartItem({
    required this.menuItemId,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.unitPrice,
    required this.imageUrl,
    this.quantity = 1,
  }) : assert(quantity > 0);

  final String menuItemId;
  final String restaurantId;
  final String restaurantName;
  final String name;

  /// Price in integer cents — see issue #8.
  final int unitPrice;
  final String imageUrl;
  final int quantity;

  int get total => unitPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menuItemId: menuItemId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      name: name,
      unitPrice: unitPrice,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_item_id': menuItemId,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'name': name,
      'unit_price': unitPrice,
      'image_url': imageUrl,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['unit_price'];
    final rawQuantity = json['quantity'];
    final unitPrice = rawPrice is num
        ? rawPrice.round()
        : int.parse(rawPrice.toString());
    final quantity = rawQuantity is num
        ? rawQuantity.toInt()
        : int.parse(rawQuantity.toString());

    if (quantity < 1 || unitPrice < 0) {
      throw const FormatException('Invalid cart item values');
    }

    return CartItem(
      menuItemId: json['menu_item_id'].toString(),
      restaurantId: json['restaurant_id'].toString(),
      restaurantName: json['restaurant_name']?.toString() ?? 'Restaurant',
      name: json['name'].toString(),
      unitPrice: unitPrice,
      imageUrl: json['image_url']?.toString() ?? '',
      quantity: quantity,
    );
  }
}
