import 'pharmacy_product.dart';

class PharmacyCartItem {
  const PharmacyCartItem({required this.product, required this.quantity});

  final PharmacyProduct product;
  final int quantity;

  double get total => product.unitPrice * quantity;

  PharmacyCartItem copyWith({int? quantity}) {
    return PharmacyCartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {'product': product.toJson(), 'quantity': quantity};
  }

  factory PharmacyCartItem.fromJson(Map<String, dynamic> json) {
    final rawQuantity = json['quantity'];
    final quantity = rawQuantity is num
        ? rawQuantity.toInt()
        : int.parse(rawQuantity.toString());
    if (quantity < 1) {
      throw const FormatException('Invalid pharmacy cart item quantity');
    }

    return PharmacyCartItem(
      product: PharmacyProduct.fromJson(
        Map<String, dynamic>.from(json['product'] as Map),
      ),
      quantity: quantity,
    );
  }
}
