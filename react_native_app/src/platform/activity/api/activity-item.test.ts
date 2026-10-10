/**
 * `ActivityItem`/`parseActivityItem` has no dedicated Flutter test file
 * (checked `flutter_app/test/` directly) -- its parsing logic is only
 * exercised indirectly through `activity_repository_test.dart`-style
 * fixtures elsewhere. This is a new, focused unit test for the real
 * contracts `parseActivityItem` enforces, ahead of this issue's own
 * `fetchActivities` (which depends on it to skip malformed rows).
 */
import { orderDetailsPath, parseActivityItem, paymentMethodLabel, paymentStatusLabel } from './activity-item';

const validRow = {
  id: 'order-1',
  service_id: 'grocery',
  title: 'Bakaara groceries',
  subtitle: 'Bakaara Mart',
  status: 'Confirmed',
  occurred_at: '2026-07-27T00:00:00.000Z',
  amount: 2400,
  details_route: '/grocery',
  payment_method: 'cash_on_delivery',
  payment_status: 'pending_collection',
};

describe('parseActivityItem', () => {
  it('parses a well-formed row', () => {
    const item = parseActivityItem(validRow);

    expect(item).toMatchObject({
      id: 'order-1',
      serviceId: 'grocery',
      title: 'Bakaara groceries',
      subtitle: 'Bakaara Mart',
      status: 'Confirmed',
      amount: 2400,
      detailsRoute: '/grocery',
      paymentMethod: 'cash_on_delivery',
      paymentStatus: 'pending_collection',
    });
    expect(item.occurredAt.toISOString()).toBe('2026-07-27T00:00:00.000Z');
  });

  it('falls back to "unknown" for an unrecognized service_id rather than throwing', () => {
    const item = parseActivityItem({ ...validRow, service_id: 'cleaning' });

    expect(item.serviceId).toBe('unknown');
  });

  it('throws on a missing required field', () => {
    const row = { ...validRow };
    delete (row as Record<string, unknown>).title;

    expect(() => parseActivityItem(row)).toThrow();
  });

  it('throws on an unparseable occurred_at', () => {
    expect(() => parseActivityItem({ ...validRow, occurred_at: 'not-a-date' })).toThrow();
  });

  it('throws on a negative amount', () => {
    expect(() => parseActivityItem({ ...validRow, amount: -1 })).toThrow();
  });

  it('rounds a numeric-typed amount', () => {
    const item = parseActivityItem({ ...validRow, amount: 2400.0 });

    expect(item.amount).toBe(2400);
  });
});

describe('paymentMethodLabel', () => {
  it('labels cash_on_delivery', () => {
    expect(paymentMethodLabel(parseActivityItem(validRow))).toBe('Cash on delivery');
  });

  it('is undefined when there is no payment method', () => {
    const row = { ...validRow };
    delete (row as Record<string, unknown>).payment_method;

    expect(paymentMethodLabel(parseActivityItem(row))).toBeUndefined();
  });
});

describe('paymentStatusLabel', () => {
  it.each([
    ['pending_collection', 'Pending collection'],
    ['collected', 'Collected'],
    ['refunded', 'Refunded'],
  ])('labels %s', (raw, label) => {
    expect(paymentStatusLabel(parseActivityItem({ ...validRow, payment_status: raw }))).toBe(label);
  });
});

describe('orderDetailsPath', () => {
  it('builds the track-order path for a recognized service', () => {
    expect(orderDetailsPath(parseActivityItem(validRow))).toBe('/track-order/grocery/order-1');
  });

  it('is undefined for an unknown service', () => {
    expect(orderDetailsPath(parseActivityItem({ ...validRow, service_id: 'cleaning' }))).toBeUndefined();
  });
});
