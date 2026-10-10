/**
 * Ports `flutter_app/test/placed_order_test.dart`'s
 * `PlacedOrder.fromRpcResponse` cases (issue #378 / P5-03).
 */
import { parsePlacedOrder } from './placed-order';

describe('parsePlacedOrder', () => {
  it('parses the single row a place_*_order RPC returns (issue #60)', () => {
    const order = parsePlacedOrder(
      [
        {
          order_id: 'order-123',
          subtotal: 1000,
          delivery_fee: 499,
          tax: 100,
          total: 1599,
        },
      ],
      'food order',
    );

    expect(order.orderId).toBe('order-123');
    expect(order.subtotal).toBe(1000);
    expect(order.deliveryFee).toBe(499);
    expect(order.tax).toBe(100);
    expect(order.total).toBe(1599);
  });

  it('rounds a numeric-typed cents field to the nearest integer', () => {
    const order = parsePlacedOrder(
      [
        {
          order_id: 'order-123',
          subtotal: 1000.0,
          delivery_fee: 250,
          tax: 0,
          total: 1250,
        },
      ],
      'grocery order',
    );

    expect(order.subtotal).toBe(1000);
  });

  it('rejects a non-array response', () => {
    expect(() => parsePlacedOrder('order-123', 'food order')).toThrow();
  });

  it('rejects an empty array response', () => {
    expect(() => parsePlacedOrder([], 'food order')).toThrow();
  });

  it('rejects a row that is missing a required field', () => {
    expect(() =>
      parsePlacedOrder(
        [
          {
            order_id: 'order-123',
            subtotal: 1000,
            delivery_fee: 499,
            // tax missing
            total: 1599,
          },
        ],
        'food order',
      ),
    ).toThrow();
  });

  it('rejects a row with a blank order id', () => {
    expect(() =>
      parsePlacedOrder(
        [
          {
            order_id: '   ',
            subtotal: 1000,
            delivery_fee: 499,
            tax: 100,
            total: 1599,
          },
        ],
        'food order',
      ),
    ).toThrow();
  });
});
