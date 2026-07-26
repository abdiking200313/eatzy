class CheckoutItem {
  const CheckoutItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String name;
  final String price;
  final int quantity;
}

class PaymentChoice {
  const PaymentChoice({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}
