class Order {
  const Order({
    required this.id,
    required this.vendor,
    required this.amount,
    required this.status,
    this.isActive = false,
  });

  final String id;
  final String vendor;
  final String amount;
  final String status;
  final bool isActive;
}
