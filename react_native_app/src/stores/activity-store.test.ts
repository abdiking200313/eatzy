/**
 * Ports the controller-level cases of `flutter_app/test/activity_controller_test.dart`
 * (issue #397 / P8-01) against `activity-store.ts`: newest-first ordering
 * with replace-by-id, and `load()` reporting the original error through
 * `ErrorReporting` while setting the generic user-facing message. The
 * screen-level cases live in `src/app/(app)/(tabs)/activity.test.tsx`; the
 * `ActivityItem.fromMap` cases in `activity-item.test.ts`.
 *
 * Also covers the RN-only additions: `refreshOrder` (the realtime path) and
 * resetting on an account change through `SessionResetRegistry`.
 */
import type { ActivityItem } from '@/platform/activity/api/activity-item';
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';

import { ACTIVITY_LOAD_ERROR, createActivityStore } from './activity-store';
import { SessionResetRegistry } from './session-reset-registry';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function activity(overrides: Partial<ActivityItem> & Pick<ActivityItem, 'id'>): ActivityItem {
  return {
    serviceId: 'food',
    title: 'Food order',
    status: 'Confirmed',
    occurredAt: new Date('2026-07-01T00:00:00Z'),
    amount: 10,
    detailsRoute: '/food',
    ...overrides,
  };
}

function build(options: Parameters<typeof createActivityStore>[0] = {}) {
  return createActivityStore({ registry: new SessionResetRegistry(), ...options });
}

describe('activity store (ports activity_controller_test.dart)', () => {
  it('keeps newest records first and replaces IDs', () => {
    const { store } = build();
    const older = new Date('2026-07-01T00:00:00Z');
    const newer = new Date('2026-07-02T00:00:00Z');

    store.getState().record(activity({ id: 'same', title: 'Food order', occurredAt: older, amount: 10 }));
    store.getState().record(activity({ id: 'grocery', serviceId: 'grocery', title: 'Grocery order', occurredAt: newer, amount: 20 }));
    store.getState().record(
      activity({ id: 'same', title: 'Updated food order', status: 'Ready', occurredAt: new Date(newer.getTime() + 3600_000), amount: 12 }),
    );

    expect(store.getState().items.map((item) => item.id)).toEqual(['same', 'grocery']);
    expect(store.getState().items[0].status).toBe('Ready');
  });

  it('load() reports the original error through ErrorReporting and still sets the generic user-facing error', async () => {
    const error = new Error('boom: repository unreachable');
    const { store } = build({ fetchActivities: () => Promise.reject(error) });
    const reported: { error: unknown; context?: string }[] = [];
    const original = ErrorReporting.instance;
    const fake: ErrorReporter = { reportError: (e, _stack, context) => reported.push({ error: e, context }) };
    ErrorReporting.instance = fake;
    try {
      await store.getState().load();
    } finally {
      ErrorReporting.instance = original;
    }

    expect(store.getState().loadError).toBe(ACTIVITY_LOAD_ERROR);
    expect(store.getState().loadError).toBe('Activity could not be loaded. Please try again.');
    expect(reported).toHaveLength(1);
    expect(reported[0].error).toBe(error);
    expect(reported[0].context).toBe('ActivityController.load');
    expect(store.getState().isLoading).toBe(false);
  });

  it('load() replaces the items with the repository result and marks the feed loaded', async () => {
    const { store } = build({
      fetchActivities: async () => [activity({ id: 'a', occurredAt: new Date('2026-07-01T00:00:00Z') }), activity({ id: 'b', occurredAt: new Date('2026-07-03T00:00:00Z') })],
    });

    await store.getState().load();

    expect(store.getState().items.map((item) => item.id)).toEqual(['b', 'a']);
    expect(store.getState().hasLoaded).toBe(true);
    expect(store.getState().loadError).toBeNull();
  });

  it('ignores a second load() while one is already running', async () => {
    let calls = 0;
    let resolve: (items: ActivityItem[]) => void = () => {};
    const { store } = build({
      fetchActivities: () => {
        calls++;
        return new Promise((r) => (resolve = r));
      },
    });

    const first = store.getState().load();
    await store.getState().load();
    resolve([]);
    await first;

    expect(calls).toBe(1);
  });

  describe('refreshOrder (realtime path)', () => {
    it('re-reads one order and records its new status in place', async () => {
      const { store } = build({
        fetchOrder: async ({ orderId }) => activity({ id: orderId, status: 'out_for_delivery' }),
      });
      store.getState().record(activity({ id: 'order-1', status: 'confirmed' }));

      await store.getState().refreshOrder({ orderId: 'order-1', serviceId: 'food' });

      expect(store.getState().items).toHaveLength(1);
      expect(store.getState().items[0].status).toBe('out_for_delivery');
    });

    it('adds a newly placed order it had not seen yet', async () => {
      const { store } = build({ fetchOrder: async ({ orderId }) => activity({ id: orderId, title: 'New order' }) });

      await store.getState().refreshOrder({ orderId: 'order-2', serviceId: 'grocery' });

      expect(store.getState().items.map((item) => item.title)).toEqual(['New order']);
    });

    it('leaves the list alone when the row is gone or the fetch fails', async () => {
      const original = ErrorReporting.instance;
      ErrorReporting.instance = { reportError: () => {} };
      try {
        const { store } = build({ fetchOrder: async () => null });
        store.getState().record(activity({ id: 'order-1' }));
        await store.getState().refreshOrder({ orderId: 'order-1', serviceId: 'food' });
        expect(store.getState().items).toHaveLength(1);

        const failing = build({ fetchOrder: () => Promise.reject(new Error('offline')) });
        failing.store.getState().record(activity({ id: 'order-1' }));
        await failing.store.getState().refreshOrder({ orderId: 'order-1', serviceId: 'food' });
        expect(failing.store.getState().items).toHaveLength(1);
      } finally {
        ErrorReporting.instance = original;
      }
    });
  });

  it('clears the feed when the account changes, and drops a load that started for the previous account', async () => {
    const registry = new SessionResetRegistry();
    let resolve: (items: ActivityItem[]) => void = () => {};
    const { store } = createActivityStore({ registry, fetchActivities: () => new Promise((r) => (resolve = r)) });
    store.getState().record(activity({ id: 'old-account-order' }));

    const pending = store.getState().load();
    registry.notifyAll('user-2');
    resolve([activity({ id: 'stale' })]);
    await pending;

    expect(store.getState().items).toEqual([]);
    expect(store.getState().hasLoaded).toBe(false);
    expect(store.getState().isLoading).toBe(false);
  });
});
