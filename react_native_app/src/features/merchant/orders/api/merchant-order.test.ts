/**
 * Ports `flutter_app/test/merchant_order_test.dart` (issue #408 / P9-03):
 * `merchantOrderFromRow`/`merchantOrderLineItemFromRow` against the real
 * per-vertical column shapes, plus the pure status-vocabulary helpers. Adds
 * RN-only coverage for the fallbacks and labels.
 */
import {
  deliveryLine,
  lineTotalCents,
  merchantOrderFromRow,
  shortOrderId,
  substitutionPreferenceLabel,
} from './merchant-order';
import { canCancelOrder, merchantOrderStatusLabel, nextForwardOrderStatus } from './merchant-order-vertical';

describe('merchantOrderFromRow (MerchantOrder.fromMap)', () => {
  it('parses a food order with its items and tax', () => {
    const order = merchantOrderFromRow(
      {
        id: 'order-1',
        status: 'confirmed',
        created_at: '2026-09-01T12:00:00Z',
        subtotal: 1000,
        delivery_fee: 499,
        tax: 100,
        total: 1599,
        recipient_name: 'Amina',
        phone: '+252-61-000-0000',
        street: 'Main St',
        district: 'Hodan',
        city: 'Mogadishu',
        payment_method: 'cash_on_delivery',
        payment_status: 'pending_collection',
        food_order_items: [{ id: 1, item_name: 'Sambusa', quantity: 2, unit_price: 250 }],
      },
      'food',
    );

    expect(order.id).toBe('order-1');
    expect(order.vertical).toBe('food');
    expect(order.status).toBe('confirmed');
    expect(order.createdAt.toISOString()).toBe('2026-09-01T12:00:00.000Z');
    expect(order.subtotalCents).toBe(1000);
    expect(order.deliveryFeeCents).toBe(499);
    expect(order.taxCents).toBe(100);
    expect(order.totalCents).toBe(1599);
    expect(order.recipientName).toBe('Amina');
    expect(order.street).toBe('Main St');
    expect(order.paymentMethod).toBe('cash_on_delivery');
    expect(order.paymentStatus).toBe('pending_collection');
    expect(order.deliverySlotLabel).toBeNull();
    expect(order.deliveryInstructions).toBeNull();
    expect(order.items).toHaveLength(1);
    expect(order.items[0].id).toBe('1');
    expect(order.items[0].name).toBe('Sambusa');
    expect(order.items[0].quantity).toBe(2);
    expect(order.items[0].unitPriceCents).toBe(250);
    expect(lineTotalCents(order.items[0])).toBe(500);
    expect(deliveryLine(order)).toBe('Main St, Hodan, Mogadishu');
  });

  it('deliveryLine skips blank parts: a note-only order shows just the note, and no note shows nothing', () => {
    const orderWith = (street: string) =>
      merchantOrderFromRow(
        {
          id: 'order-3',
          status: 'confirmed',
          created_at: '2026-09-25T12:00:00Z',
          subtotal: 1000,
          delivery_fee: 499,
          tax: 100,
          total: 1599,
          recipient_name: 'Amina',
          phone: '+252-61-000-0000',
          street,
          district: '',
          city: '',
          food_order_items: [],
        },
        'food',
      );

    expect(deliveryLine(orderWith('Blue gate'))).toBe('Blue gate');
    expect(deliveryLine(orderWith(''))).toBe('');
  });

  it('parses a grocery order with a fractional-quantity item', () => {
    const order = merchantOrderFromRow(
      {
        id: 'order-2',
        status: 'shopping',
        created_at: '2026-09-01T12:00:00Z',
        subtotal: 800,
        delivery_fee: 250,
        total: 1050,
        recipient_name: 'Farah',
        phone: '+252-61-111-1111',
        street: 'Second St',
        district: 'Waberi',
        city: 'Mogadishu',
        delivery_slot_label: 'Today 4-6pm',
        substitution_preference: 'contact_me',
        grocery_order_items: [{ id: 1, product_name: 'Bananas', quantity: 2.5, unit_price: 100 }],
      },
      'grocery',
    );

    expect(order.taxCents).toBeNull();
    expect(order.deliverySlotLabel).toBe('Today 4-6pm');
    expect(substitutionPreferenceLabel(order.substitutionPreference)).toBe('Contact me before substituting');
    expect(order.items[0].quantity).toBe(2.5);
    // 100 cents * 2.5 = 250 cents exactly.
    expect(lineTotalCents(order.items[0])).toBe(250);
  });

  it('parses a pharmacy order with delivery instructions', () => {
    const order = merchantOrderFromRow(
      {
        id: 'order-3',
        status: 'packing',
        created_at: '2026-09-01T12:00:00Z',
        subtotal: 500,
        delivery_fee: 250,
        total: 750,
        recipient_name: 'Hodan',
        phone: '+252-61-222-2222',
        street: 'Third St',
        district: 'Karan',
        city: 'Mogadishu',
        delivery_instructions: 'Leave with the gate guard',
        pharmacy_order_items: [{ id: 1, product_name: 'Paracetamol', quantity: 1, unit_price: 500 }],
      },
      'pharmacy',
    );

    expect(order.deliveryInstructions).toBe('Leave with the gate guard');
    expect(order.deliverySlotLabel).toBeNull();
    expect(order.items[0].name).toBe('Paracetamol');
  });

  it('defaults missing items to an empty list', () => {
    const order = merchantOrderFromRow(
      {
        id: 'order-4',
        status: 'confirmed',
        created_at: '2026-09-01T12:00:00Z',
        subtotal: 0,
        delivery_fee: 0,
        total: 0,
        recipient_name: '',
        phone: '',
        street: '',
        district: '',
        city: '',
      },
      'food',
    );

    expect(order.items).toEqual([]);
  });

  it('RN-only: falls back for missing status/created_at/money and ignores other verticals’ columns', () => {
    const order = merchantOrderFromRow(
      { id: 'order-5', tax: 100, delivery_slot_label: 'Today', delivery_instructions: 'Ring' },
      'pharmacy',
    );

    expect(order.status).toBe('confirmed');
    expect(order.createdAt.getTime()).toBe(0);
    expect(order.totalCents).toBe(0);
    expect(order.taxCents).toBeNull();
    expect(order.deliverySlotLabel).toBeNull();
    expect(order.deliveryInstructions).toBe('Ring');
    expect(order.paymentMethod).toBeNull();
  });
});

describe('status vocabulary helpers', () => {
  it('nextForwardOrderStatus advances one step at a time per vertical', () => {
    expect(nextForwardOrderStatus('food', 'confirmed')).toBe('preparing');
    expect(nextForwardOrderStatus('food', 'preparing')).toBe('out_for_delivery');
    expect(nextForwardOrderStatus('food', 'out_for_delivery')).toBe('delivered');
    expect(nextForwardOrderStatus('food', 'delivered')).toBeNull();
    expect(nextForwardOrderStatus('food', 'cancelled')).toBeNull();

    expect(nextForwardOrderStatus('grocery', 'confirmed')).toBe('shopping');
    expect(nextForwardOrderStatus('pharmacy', 'confirmed')).toBe('packing');
  });

  it('canCancelOrder allows only the first two forward states', () => {
    expect(canCancelOrder('food', 'confirmed')).toBe(true);
    expect(canCancelOrder('food', 'preparing')).toBe(true);
    expect(canCancelOrder('food', 'out_for_delivery')).toBe(false);
    expect(canCancelOrder('food', 'delivered')).toBe(false);
  });

  it('merchantOrderStatusLabel renders every real status value', () => {
    expect(merchantOrderStatusLabel('confirmed')).toBe('Confirmed');
    expect(merchantOrderStatusLabel('out_for_delivery')).toBe('Out for delivery');
    expect(merchantOrderStatusLabel('cancelled')).toBe('Cancelled');
  });

  it('RN-only: unknown labels and substitution values fall back to the raw string; shortOrderId trims to 8', () => {
    expect(merchantOrderStatusLabel('on_hold')).toBe('on_hold');
    expect(merchantOrderStatusLabel('toString')).toBe('toString');
    expect(substitutionPreferenceLabel(null)).toBeNull();
    expect(substitutionPreferenceLabel('best_match')).toBe('Substitute with best match');
    expect(substitutionPreferenceLabel('no_substitutions')).toBe('No substitutions');
    expect(substitutionPreferenceLabel('other')).toBe('other');
    expect(shortOrderId('1234abcd-5678')).toBe('1234abcd');
    expect(shortOrderId('short')).toBe('short');
  });
});
