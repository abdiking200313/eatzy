/**
 * Ports the screen-level cases of `flutter_app/test/activity_controller_test.dart`
 * (issue #397 / P8-01): rendering unified service records, pull-to-refresh
 * reloading from the repository, and tapping a row opening its order details
 * (or doing nothing for an unrecognized service). Adds the RN-only realtime
 * acceptance criterion: a status change pushed from the database updates the
 * row without a refresh.
 *
 * Every case injects its own isolated store (`createActivityStore`) and a
 * fake `watch` (the Realtime subscription), so nothing touches Supabase;
 * `@/platform/supabase/client` is still stubbed because `session-store.ts`
 * builds its singleton (calling `auth.onAuthStateChange`) on import.
 */
import { act, fireEvent, screen, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';

import type { ActivityItem } from '@/platform/activity/api/activity-item';
import type { CustomerOrderChange } from '@/platform/activity/api/activity-repository';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { createActivityStore } from '@/stores/activity-store';
import { SessionResetRegistry } from '@/stores/session-reset-registry';
import { renderWithProviders } from '@/test-utils';

import ActivityScreen from './activity';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), canGoBack: jest.fn(() => false), back: jest.fn(), replace: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));

function activity(overrides: Partial<ActivityItem> & Pick<ActivityItem, 'id'>): ActivityItem {
  return {
    serviceId: 'food',
    title: 'Food order',
    status: 'Confirmed',
    occurredAt: new Date('2026-07-27T00:00:00Z'),
    amount: 10,
    detailsRoute: '',
    ...overrides,
  };
}

function buildStore(options: Parameters<typeof createActivityStore>[0] = {}) {
  return createActivityStore({ registry: new SessionResetRegistry(), fetchActivities: async () => [], ...options }).store;
}

/** A fake `watch` capturing the change callback, so a test can push a "database" change. */
function fakeWatch() {
  const state: { onChange?: (change: CustomerOrderChange) => void; profileId?: string; stopped: boolean } = { stopped: false };
  const watch = jest.fn((profileId: string, onChange: (change: CustomerOrderChange) => void) => {
    state.profileId = profileId;
    state.onChange = onChange;
    return () => {
      state.stopped = true;
    };
  });
  return { watch, state };
}

const noWatch = () => () => {};

beforeEach(() => {
  jest.mocked(router.push).mockClear();
});

describe('ActivityScreen', () => {
  it('renders unified service records', async () => {
    const store = buildStore();
    store.getState().record(activity({ id: 'pharmacy-1', serviceId: 'pharmacy', title: 'Pharmacy order', status: 'MVP confirmed', amount: 5400 }));

    await renderWithProviders(<ActivityScreen store={store} userId={null} watch={noWatch} />);

    expect(screen.getByText('Pharmacy order')).toBeOnTheScreen();
    expect(screen.getByText('$54.00')).toBeOnTheScreen();
    expect(screen.getByText('MVP confirmed')).toBeOnTheScreen();
  });

  it('pulling to refresh reloads activity from the repository', async () => {
    let fetchCount = 0;
    const store = buildStore({
      fetchActivities: async () => {
        fetchCount++;
        return [];
      },
    });
    await store.getState().load();
    expect(fetchCount).toBe(1);

    await renderWithProviders(<ActivityScreen store={store} userId={null} watch={noWatch} />);
    expect(screen.getByText('No activity yet')).toBeOnTheScreen();

    const list = screen.getByTestId('activity-list');
    await act(async () => {
      await list.props.refreshControl.props.onRefresh();
    });

    await waitFor(() => expect(fetchCount).toBe(2));
  });

  describe('tapping an order row opens its order details', () => {
    it("a real-service row navigates to trackOrderDetails with that row's service/order id", async () => {
      const store = buildStore();
      store.getState().record(activity({ id: 'food-1', title: 'Jollof Feast Order', status: 'On the way', amount: 1850, detailsRoute: '/food' }));

      await renderWithProviders(<ActivityScreen store={store} userId={null} watch={noWatch} />);

      // No "Order again" on the row: it lives on the order details page.
      expect(screen.queryByText('Order again')).toBeNull();

      await fireEvent.press(screen.getByText('Jollof Feast Order'));

      expect(router.push).toHaveBeenCalledWith('/track-order/food/food-1');
    });

    it('a row with an unrecognized service does not navigate', async () => {
      const store = buildStore();
      store.getState().record(activity({ id: 'unknown-1', serviceId: 'unknown', title: 'Mystery order', status: 'completed' }));

      await renderWithProviders(<ActivityScreen store={store} userId={null} watch={noWatch} />);
      await fireEvent.press(screen.getByText('Mystery order'));

      expect(router.push).not.toHaveBeenCalled();
      expect(screen.getByText('Mystery order')).toBeOnTheScreen();
    });
  });

  it('shows the error with a retry that reloads', async () => {
    const original = ErrorReporting.instance;
    ErrorReporting.instance = { reportError: () => {} };
    try {
      let attempt = 0;
      const store = buildStore({
        fetchActivities: async () => {
          attempt++;
          if (attempt === 1) throw new Error('offline');
          return [activity({ id: 'food-1', title: 'Back online order' })];
        },
      });

      await renderWithProviders(<ActivityScreen store={store} userId="user-1" watch={noWatch} />);

      expect(await screen.findByText('Activity could not be loaded. Please try again.')).toBeOnTheScreen();
      await fireEvent.press(screen.getByText('Try again'));
      expect(await screen.findByText('Back online order')).toBeOnTheScreen();
    } finally {
      ErrorReporting.instance = original;
    }
  });

  it('loads the feed for the signed-in user on mount', async () => {
    const store = buildStore({ fetchActivities: async () => [activity({ id: 'grocery-1', serviceId: 'grocery', title: 'Bakaara groceries' })] });

    await renderWithProviders(<ActivityScreen store={store} userId="user-1" watch={noWatch} />);

    expect(await screen.findByText('Bakaara groceries')).toBeOnTheScreen();
  });

  describe('realtime', () => {
    it('a status change made in the database appears without a refresh', async () => {
      const statuses: Record<string, string> = { 'food-1': 'confirmed' };
      const store = buildStore({
        fetchActivities: async () => [activity({ id: 'food-1', title: 'Jollof Feast Order', status: statuses['food-1'] })],
        fetchOrder: async ({ orderId }) => activity({ id: orderId, title: 'Jollof Feast Order', status: statuses[orderId] }),
      });
      const { watch, state } = fakeWatch();

      await renderWithProviders(<ActivityScreen store={store} userId="user-1" watch={watch} />);
      expect(await screen.findByText('confirmed')).toBeOnTheScreen();
      expect(state.profileId).toBe('user-1');

      statuses['food-1'] = 'out_for_delivery';
      await act(async () => {
        state.onChange?.({ serviceId: 'food', orderId: 'food-1' });
      });

      expect(await screen.findByText('out_for_delivery')).toBeOnTheScreen();
      expect(screen.queryByText('confirmed')).toBeNull();
    });

    it('does not subscribe while signed out, and unsubscribes on unmount', async () => {
      const signedOut = fakeWatch();
      await renderWithProviders(<ActivityScreen store={buildStore()} userId={null} watch={signedOut.watch} />);
      expect(signedOut.watch).not.toHaveBeenCalled();

      const signedIn = fakeWatch();
      const { unmount } = await renderWithProviders(<ActivityScreen store={buildStore()} userId="user-1" watch={signedIn.watch} />);
      expect(signedIn.watch).toHaveBeenCalledTimes(1);
      await act(async () => {
        unmount();
      });
      expect(signedIn.state.stopped).toBe(true);
    });
  });
});
