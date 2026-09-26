import '../../../app/service_module.dart';
import 'activity_item.dart';

/// One line of a past order, at the price paid then (integer cents).
class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.pricingUnit,
  });

  final String name;

  /// Whole for food/pharmacy; grocery `kilogram` lines can be fractional.
  final num quantity;
  final int unitPrice;

  /// Grocery only: `each` or `kilogram`.
  final String? pricingUnit;

  int get lineTotal => (unitPrice * quantity).round();

  String get quantityLabel {
    final amount = quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity.toString();
    return pricingUnit == 'kilogram' ? '$amount kg' : '${amount}x';
  }
}

/// A customer's own order as shown on the order details page: the
/// `customer_activity` summary plus the order row's lines, charges and
/// delivery address. Read back from `food_orders` / `grocery_orders` /
/// `pharmacy_orders` (cents since
/// `20260903000000_convert_money_columns_to_cents.sql`; the address columns
/// are nullable since `20260927010000_make_delivery_address_optional.sql`).
class OrderDetails {
  const OrderDetails({
    required this.summary,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.tax,
    this.storeName,
    this.recipientName,
    this.phone,
    this.street,
    this.district,
    this.city,
    this.deliveryNote,
  });

  final ActivityItem summary;
  final List<OrderLine> lines;
  final int subtotal;
  final int deliveryFee;

  /// Food only.
  final int? tax;
  final int total;
  final String? storeName;
  final String? recipientName;
  final String? phone;
  final String? street;
  final String? district;
  final String? city;

  /// Grocery delivery slot or pharmacy delivery instructions.
  final String? deliveryNote;

  String get id => summary.id;
  ServiceId get serviceId => summary.serviceId;
  String get status => summary.status;

  /// "Street, District, City" with blank parts dropped; `null` when the
  /// order has no address at all.
  String? get addressLine {
    final parts = [
      for (final part in [street, district, city])
        if (part != null && part.isNotEmpty) part,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  bool get isCancelled => status == 'cancelled';

  /// The forward status steps for this order's vertical, matching
  /// `is_legal_order_status_transition` in
  /// `20260830140000_add_order_status_transition_rpcs.sql`.
  List<String> get statusFlow => [
    'confirmed',
    switch (serviceId) {
      ServiceId.grocery => 'shopping',
      ServiceId.pharmacy => 'packing',
      _ => 'preparing',
    },
    'out_for_delivery',
    'delivered',
  ];

  /// Index of [status] in [statusFlow], or -1 when unknown/cancelled.
  int get statusStep => statusFlow.indexOf(status);

  factory OrderDetails.fromOrderRow(
    ActivityItem summary,
    Map<String, dynamic> row, {
    required String itemsKey,
    required String itemNameColumn,
  }) {
    final rawLines = row[itemsKey];
    return OrderDetails(
      summary: summary,
      lines: [
        if (rawLines is List)
          for (final line in rawLines)
            if (line is Map)
              OrderLine(
                name: line[itemNameColumn]?.toString() ?? 'Item',
                quantity: (line['quantity'] as num?) ?? 1,
                unitPrice: _cents(line['unit_price']),
                pricingUnit: _text(line['pricing_unit']),
              ),
      ],
      subtotal: _cents(row['subtotal']),
      deliveryFee: _cents(row['delivery_fee']),
      tax: row.containsKey('tax') ? _cents(row['tax']) : null,
      total: _cents(row['total']),
      storeName: _text(row['restaurant_name']) ?? _text(row['store_name']),
      recipientName: _text(row['recipient_name']),
      phone: _text(row['phone']),
      street: _text(row['street']),
      district: _text(row['district']),
      city: _text(row['city']),
      deliveryNote:
          _text(row['delivery_slot_label']) ??
          _text(row['delivery_instructions']),
    );
  }
}

/// Human-readable label for a raw order status value.
String orderStatusLabel(String status) => switch (status) {
  'confirmed' => 'Confirmed',
  'preparing' => 'Preparing',
  'shopping' => 'Shopping',
  'packing' => 'Packing',
  'out_for_delivery' => 'Out for delivery',
  'delivered' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => status,
};

int _cents(Object? value) => value is num ? value.round() : 0;

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
