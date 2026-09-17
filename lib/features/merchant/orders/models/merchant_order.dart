import '../../store/models/merchant_vertical.dart';
import 'merchant_order_vertical.dart';

/// One line item on a [MerchantOrder], from whichever `_order_items` table
/// [MerchantOrderVerticalConfig.orderItemsTable] names. Ported from
/// `merchant_app` (originally issue #134, unified into the main app by
/// issue #232).
class MerchantOrderLineItem {
  const MerchantOrderLineItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
  });

  final String id;
  final String name;

  /// `food_order_items.quantity` / `pharmacy_order_items.quantity` are
  /// integers; `grocery_order_items.quantity` is `numeric(12, 2)` (weighted
  /// items, e.g. `2.5` kilograms) -- `num` covers both without forcing a
  /// fractional quantity to round.
  final num quantity;

  /// Integer cents -- see `merchant_order_vertical.dart`'s header.
  final int unitPriceCents;

  /// `unitPriceCents * quantity`, rounded to the nearest cent (only
  /// meaningful to round for grocery's fractional quantities).
  int get lineTotalCents => (unitPriceCents * quantity).round();

  factory MerchantOrderLineItem.fromMap(
    Map<String, dynamic> map, {
    required MerchantVertical vertical,
  }) {
    return MerchantOrderLineItem(
      id: map['id'].toString(),
      name: map[vertical.orderItemNameColumn] as String? ?? '',
      quantity: (map['quantity'] as num?) ?? 0,
      unitPriceCents: (map['unit_price'] as num?)?.round() ?? 0,
    );
  }
}

/// One order row from whichever vertical table
/// [MerchantOrderVerticalConfig.orderTable] names, for the merchant
/// incoming-order queue and fulfillment screens (originally issue #134).
/// See `merchant_order_vertical.dart`'s header for exactly which migrations
/// each field is verified against.
class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.vertical,
    required this.status,
    required this.createdAt,
    required this.subtotalCents,
    required this.deliveryFeeCents,
    required this.totalCents,
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.district,
    required this.city,
    required this.items,
    this.taxCents,
    this.deliverySlotLabel,
    this.substitutionPreference,
    this.deliveryInstructions,
    this.paymentMethod,
    this.paymentStatus,
  });

  final String id;
  final MerchantVertical vertical;
  final String status;
  final DateTime createdAt;

  /// All money fields are integer cents (see `AGENTS.md` / issue #8) --
  /// convert to a decimal-dollar string only at display time, via
  /// `AppMoney.formatCents`.
  final int subtotalCents;
  final int deliveryFeeCents;

  /// `food_orders.tax` only -- `null` for grocery/pharmacy, which have no
  /// tax column.
  final int? taxCents;
  final int totalCents;

  /// Contact/address snapshot captured at checkout. All three order tables
  /// share these exact column names since
  /// `20260917000000_add_shared_delivery_addresses.sql` renamed pharmacy's
  /// `customer_name`/`phone_number`/`address_line` to match food/grocery's
  /// existing `recipient_name`/`phone`/`street`.
  final String recipientName;
  final String phone;
  final String street;
  final String district;
  final String city;

  /// `grocery_orders.delivery_slot_label` only.
  final String? deliverySlotLabel;

  /// `grocery_orders.substitution_preference` only (raw column value: one
  /// of `best_match` / `contact_me` / `no_substitutions`).
  final String? substitutionPreference;

  /// `pharmacy_orders.delivery_instructions` only.
  final String? deliveryInstructions;

  /// Raw `payment_method` / `payment_status` values (cash-on-delivery-only
  /// launch scaffolding, issue #30) -- both `null` for a legacy row from
  /// before those columns existed.
  final String? paymentMethod;
  final String? paymentStatus;

  final List<MerchantOrderLineItem> items;

  factory MerchantOrder.fromMap(
    Map<String, dynamic> map, {
    required MerchantVertical vertical,
  }) {
    final rawCreatedAt = map['created_at'] as String?;
    final rawItems =
        map[vertical.orderItemsTable] as List<dynamic>? ?? const [];
    return MerchantOrder(
      id: map['id'] as String,
      vertical: vertical,
      status: map['status'] as String? ?? 'confirmed',
      createdAt:
          (rawCreatedAt != null ? DateTime.tryParse(rawCreatedAt) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      subtotalCents: (map['subtotal'] as num?)?.round() ?? 0,
      deliveryFeeCents: (map['delivery_fee'] as num?)?.round() ?? 0,
      taxCents: vertical.orderHasTax
          ? (map['tax'] as num?)?.round() ?? 0
          : null,
      totalCents: (map['total'] as num?)?.round() ?? 0,
      recipientName: map['recipient_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      street: map['street'] as String? ?? '',
      district: map['district'] as String? ?? '',
      city: map['city'] as String? ?? '',
      deliverySlotLabel: vertical.orderHasDeliverySlot
          ? map['delivery_slot_label'] as String?
          : null,
      substitutionPreference: vertical.orderHasDeliverySlot
          ? map['substitution_preference'] as String?
          : null,
      deliveryInstructions: vertical.orderHasDeliveryInstructions
          ? map['delivery_instructions'] as String?
          : null,
      paymentMethod: map['payment_method'] as String?,
      paymentStatus: map['payment_status'] as String?,
      items: List.unmodifiable(
        rawItems.map(
          (item) => MerchantOrderLineItem.fromMap(
            item as Map<String, dynamic>,
            vertical: vertical,
          ),
        ),
      ),
    );
  }

  MerchantOrder copyWith({String? status}) {
    return MerchantOrder(
      id: id,
      vertical: vertical,
      status: status ?? this.status,
      createdAt: createdAt,
      subtotalCents: subtotalCents,
      deliveryFeeCents: deliveryFeeCents,
      taxCents: taxCents,
      totalCents: totalCents,
      recipientName: recipientName,
      phone: phone,
      street: street,
      district: district,
      city: city,
      deliverySlotLabel: deliverySlotLabel,
      substitutionPreference: substitutionPreference,
      deliveryInstructions: deliveryInstructions,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      items: items,
    );
  }
}

/// The first 8 characters of [orderId] (a uuid), for a compact "Order
/// #1234abcd" display -- shared by the order list and detail screens so
/// they always show the same shortened id for the same order.
String shortOrderId(String orderId) =>
    orderId.length <= 8 ? orderId : orderId.substring(0, 8);

/// Human-readable label for [MerchantOrder.substitutionPreference]. Mirrors
/// the raw values' meaning; falls back to the raw string for anything
/// unrecognized rather than dropping it.
String? substitutionPreferenceLabel(String? raw) => switch (raw) {
  null => null,
  'best_match' => 'Substitute with best match',
  'contact_me' => 'Contact me before substituting',
  'no_substitutions' => 'No substitutions',
  final other => other,
};
