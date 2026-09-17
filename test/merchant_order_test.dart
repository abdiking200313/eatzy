import 'package:chowflow/features/merchant/orders/models/merchant_order.dart';
import 'package:chowflow/features/merchant/orders/models/merchant_order_vertical.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit-tests `MerchantOrder.fromMap`/`MerchantOrderLineItem.fromMap` against
// the real per-vertical column shapes (ported from `merchant_app`,
// originally issue #134, unified into the main app by issue #232) -- see
// `merchant_order_vertical.dart`'s header for exactly which migrations these
// are verified against -- plus the pure status-vocabulary helpers.
void main() {
  group('MerchantOrder.fromMap', () {
    test('parses a food order with its items and tax', () {
      final order = MerchantOrder.fromMap({
        'id': 'order-1',
        'status': 'confirmed',
        'created_at': '2026-09-01T12:00:00Z',
        'subtotal': 1000,
        'delivery_fee': 499,
        'tax': 100,
        'total': 1599,
        'recipient_name': 'Amina',
        'phone': '+252-61-000-0000',
        'street': 'Main St',
        'district': 'Hodan',
        'city': 'Mogadishu',
        'payment_method': 'cash_on_delivery',
        'payment_status': 'pending_collection',
        'food_order_items': [
          {'id': 1, 'item_name': 'Sambusa', 'quantity': 2, 'unit_price': 250},
        ],
      }, vertical: MerchantVertical.food);

      expect(order.id, 'order-1');
      expect(order.vertical, MerchantVertical.food);
      expect(order.status, 'confirmed');
      expect(order.subtotalCents, 1000);
      expect(order.deliveryFeeCents, 499);
      expect(order.taxCents, 100);
      expect(order.totalCents, 1599);
      expect(order.recipientName, 'Amina');
      expect(order.street, 'Main St');
      expect(order.deliverySlotLabel, isNull);
      expect(order.deliveryInstructions, isNull);
      expect(order.items, hasLength(1));
      expect(order.items.single.name, 'Sambusa');
      expect(order.items.single.quantity, 2);
      expect(order.items.single.unitPriceCents, 250);
      expect(order.items.single.lineTotalCents, 500);
    });

    test('parses a grocery order with a fractional-quantity item', () {
      final order = MerchantOrder.fromMap({
        'id': 'order-2',
        'status': 'shopping',
        'created_at': '2026-09-01T12:00:00Z',
        'subtotal': 800,
        'delivery_fee': 250,
        'total': 1050,
        'recipient_name': 'Farah',
        'phone': '+252-61-111-1111',
        'street': 'Second St',
        'district': 'Waberi',
        'city': 'Mogadishu',
        'delivery_slot_label': 'Today 4-6pm',
        'substitution_preference': 'contact_me',
        'grocery_order_items': [
          {
            'id': 1,
            'product_name': 'Bananas',
            'quantity': 2.5,
            'unit_price': 100,
          },
        ],
      }, vertical: MerchantVertical.grocery);

      expect(order.taxCents, isNull);
      expect(order.deliverySlotLabel, 'Today 4-6pm');
      expect(
        substitutionPreferenceLabel(order.substitutionPreference),
        'Contact me before substituting',
      );
      expect(order.items.single.quantity, 2.5);
      // 100 cents * 2.5 = 250 cents exactly.
      expect(order.items.single.lineTotalCents, 250);
    });

    test('parses a pharmacy order with delivery instructions', () {
      final order = MerchantOrder.fromMap({
        'id': 'order-3',
        'status': 'packing',
        'created_at': '2026-09-01T12:00:00Z',
        'subtotal': 500,
        'delivery_fee': 250,
        'total': 750,
        'recipient_name': 'Hodan',
        'phone': '+252-61-222-2222',
        'street': 'Third St',
        'district': 'Karan',
        'city': 'Mogadishu',
        'delivery_instructions': 'Leave with the gate guard',
        'pharmacy_order_items': [
          {
            'id': 1,
            'product_name': 'Paracetamol',
            'quantity': 1,
            'unit_price': 500,
          },
        ],
      }, vertical: MerchantVertical.pharmacy);

      expect(order.deliveryInstructions, 'Leave with the gate guard');
      expect(order.deliverySlotLabel, isNull);
      expect(order.items.single.name, 'Paracetamol');
    });

    test('defaults missing items to an empty list', () {
      final order = MerchantOrder.fromMap({
        'id': 'order-4',
        'status': 'confirmed',
        'created_at': '2026-09-01T12:00:00Z',
        'subtotal': 0,
        'delivery_fee': 0,
        'total': 0,
        'recipient_name': '',
        'phone': '',
        'street': '',
        'district': '',
        'city': '',
      }, vertical: MerchantVertical.food);

      expect(order.items, isEmpty);
    });
  });

  group('status vocabulary helpers', () {
    test('nextForwardOrderStatus advances one step at a time per vertical', () {
      expect(
        nextForwardOrderStatus(MerchantVertical.food, 'confirmed'),
        'preparing',
      );
      expect(
        nextForwardOrderStatus(MerchantVertical.food, 'preparing'),
        'out_for_delivery',
      );
      expect(
        nextForwardOrderStatus(MerchantVertical.food, 'out_for_delivery'),
        'delivered',
      );
      expect(
        nextForwardOrderStatus(MerchantVertical.food, 'delivered'),
        isNull,
      );
      expect(
        nextForwardOrderStatus(MerchantVertical.food, 'cancelled'),
        isNull,
      );

      expect(
        nextForwardOrderStatus(MerchantVertical.grocery, 'confirmed'),
        'shopping',
      );
      expect(
        nextForwardOrderStatus(MerchantVertical.pharmacy, 'confirmed'),
        'packing',
      );
    });

    test('canCancelOrder allows only the first two forward states', () {
      expect(canCancelOrder(MerchantVertical.food, 'confirmed'), isTrue);
      expect(canCancelOrder(MerchantVertical.food, 'preparing'), isTrue);
      expect(
        canCancelOrder(MerchantVertical.food, 'out_for_delivery'),
        isFalse,
      );
      expect(canCancelOrder(MerchantVertical.food, 'delivered'), isFalse);
    });

    test('merchantOrderStatusLabel renders every real status value', () {
      expect(merchantOrderStatusLabel('confirmed'), 'Confirmed');
      expect(merchantOrderStatusLabel('out_for_delivery'), 'Out for delivery');
      expect(merchantOrderStatusLabel('cancelled'), 'Cancelled');
    });
  });
}
