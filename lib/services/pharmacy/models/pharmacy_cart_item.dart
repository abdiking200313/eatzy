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
}
