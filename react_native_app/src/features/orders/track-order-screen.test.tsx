/**
 * Ports `flutter_app/test/track_order_screen_test.dart` (issue #398 / P8-02)
 * case for case: the order details content (header, real progress
 * timeline, items/charges, address, payment, "Order again"), the cancelled
 * and grocery-weight variants, the "no order selected"/"not found"/"retry"
 * states, and the issue #297 live-update group (a realtime tick refetches
 * and re-renders without resubscribing; the subscription is torn down on
 * unmount; a final-state order is never watched).
 *
 * The data layer is injected (`fetchDetails`, plus a fake `watch` standing
 * in for the Supabase Realtime channel), so nothing touches Supabase;
 * `@/platform/supabase/client` is still stubbed because the default
 * repository/session modules import it.
 */
import { act, fireEvent, screen, waitFor } from '@testing-library/react-native';

import type { ActivityItem } from '@/platform/activity/api/activity-item';
import type { ReorderBasket } from '@/platform/activity/api/order-again-repository';
import type { OrderDetails } from '@/platform/activity/api/order-details';
import { AppRoutes } from '@/platform/navigation/app-routes';
import type { OrderAgainService } from '@/platform/activity/order-again-service';
import type { OrderReference } from '@/platform/activity/use-order-details';
import { renderWithProviders } from '@/test-utils';

import { TrackOrderScreen } from './track-order-screen';
import { trackingSteps } from './tracking-card';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), navigate: jest.fn(), canGoBack: jest.fn(() => false), back: jest.fn(), replace: jest.fn() },
}));

jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));

const ORDER_ID = '3f2a9c1e-0000-4000-8000-000000000001';

function summary(overrides: Partial<ActivityItem> = {}): ActivityItem {
  return {
    id: ORDER_ID,
    serviceId: 'food',
    title: 'Jollof Feast Order',
    status: 'preparing',
    occurredAt: new Date(Date.UTC(2026, 7, 1, 12)),
    amount: 2950,
    detailsRoute: '/food',
    ...overrides,
  };
}

function details(item: ActivityItem, overrides: Partial<OrderDetails> = {}): OrderDetails {
  return {
    summary: item,
    storeName: 'Jollof Feast',
    lines: [
      { name: 'Jollof Rice', quantity: 2, unitPrice: 1000 },
      { name: 'Plantain', quantity: 1, unitPrice: 450 },
    ],
    subtotal: 2450,
    deliveryFee: 300,
    tax: 200,
    total: 2950,
    recipientName: 'Amina',
    phone: '+252 61 000 0000',
    street: 'Maka Al Mukarama',
    district: 'Hodan',
    city: 'Mogadishu',
    ...overrides,
  };
}

/** Ports `_FakeOrderDetailsRepository`: a mutable order plus a fake realtime watch. */
function fakeRepository(initial: OrderDetails | null) {
  const state = {
    order: initial,
    watchCallCount: 0,
    watchStopped: false,
    lastReference: undefined as OrderReference | undefined,
    onChange: undefined as (() => void) | undefined,
  };
  const fetchDetails = jest.fn(async () => state.order);
  const watch = jest.fn((reference: OrderReference, onChange: () => void) => {
    state.watchCallCount++;
    state.lastReference = reference;
    state.onChange = onChange;
    return () => {
      state.watchStopped = true;
    };
  });
  /** Simulates a realtime `postgres_changes` event firing. */
  const emitOrderChanged = () => state.onChange?.();
  return { state, fetchDetails, watch, emitOrderChanged };
}

async function renderScreen(repo: ReturnType<typeof fakeRepository>, props: Partial<Parameters<typeof TrackOrderScreen>[0]> = {}) {
  const result = await renderWithProviders(
    <TrackOrderScreen orderId={ORDER_ID} serviceId="food" fetchDetails={repo.fetchDetails} watch={repo.watch} {...props} />,
  );
  await waitFor(() => expect(screen.queryByTestId('loading-state')).toBeNull());
  return result;
}

describe('TrackOrderScreen order details', () => {
  it('shows the order, its items, charges, address and a real progress timeline', async () => {
    await renderScreen(fakeRepository(details(summary())));

    expect(screen.getByText('Order details')).toBeOnTheScreen();
    expect(screen.getByText('Jollof Feast')).toBeOnTheScreen();
    expect(screen.getByText('Order #3F2A9C1E')).toBeOnTheScreen();

    // Timeline: every step of the food flow, current one included.
    expect(screen.getByText('Track order')).toBeOnTheScreen();
    for (const step of ['Confirmed', 'Out for delivery', 'Delivered']) {
      expect(screen.getByText(step)).toBeOnTheScreen();
    }
    // "Preparing" is both the status pill and the current step.
    expect(screen.getAllByText('Preparing')).toHaveLength(2);

    expect(screen.getByText('2x')).toBeOnTheScreen();
    expect(screen.getByText('Jollof Rice')).toBeOnTheScreen();
    expect(screen.getByText('Plantain')).toBeOnTheScreen();
    expect(screen.getByText('Subtotal')).toBeOnTheScreen();
    expect(screen.getByText('Delivery fee')).toBeOnTheScreen();
    expect(screen.getByText('Tax')).toBeOnTheScreen();
    expect(screen.getByText('Total')).toBeOnTheScreen();

    expect(screen.getByText('Delivery address')).toBeOnTheScreen();
    expect(screen.getByText('Maka Al Mukarama, Hodan, Mogadishu')).toBeOnTheScreen();

    // No fabricated courier or ETA anywhere on screen.
    expect(screen.queryByText(/minutes/)).toBeNull();
    // No customer cancel action: the Flutter app has none.
    expect(screen.queryByText(/cancel/i)).toBeNull();

    // No payment card when the order has no payment fields.
    expect(screen.queryByText('Payment')).toBeNull();

    expect(screen.getByText('Order again')).toBeOnTheScreen();
  });

  it('marks steps up to the current status as completed', () => {
    expect(trackingSteps(details(summary({ status: 'preparing' })))).toEqual([
      { label: 'Confirmed', isCompleted: true, hasConnector: true },
      { label: 'Preparing', isCompleted: true, hasConnector: true },
      { label: 'Out for delivery', isCompleted: false, hasConnector: true },
      { label: 'Delivered', isCompleted: false, hasConnector: false },
    ]);
    // An unknown status is shown as-is rather than guessed into the flow.
    expect(trackingSteps(details(summary({ status: 'on_hold' })))).toEqual([{ label: 'on_hold', isCompleted: true, hasConnector: false }]);
  });

  it('a cancelled order shows a cancelled step, not the flow', async () => {
    await renderScreen(fakeRepository(details(summary({ status: 'cancelled' }))));

    expect(screen.getByText('Order cancelled')).toBeOnTheScreen();
    expect(screen.queryByText('Out for delivery')).toBeNull();
  });

  it('grocery kilogram lines show their weight', async () => {
    await renderScreen(
      fakeRepository({
        summary: summary({ serviceId: 'grocery', status: 'shopping' }),
        lines: [{ name: 'Tomatoes', quantity: 1.5, unitPrice: 200, pricingUnit: 'kilogram' }],
        subtotal: 300,
        deliveryFee: 0,
        total: 300,
      }),
      { serviceId: 'grocery' },
    );

    expect(screen.getByText('1.5 kg')).toBeOnTheScreen();
    expect(screen.getAllByText('Shopping')).toHaveLength(2);
    // No address stored: no empty address card.
    expect(screen.queryByText('Delivery address')).toBeNull();
  });

  it("shows the order's real payment method and status (issue #30)", async () => {
    await renderScreen(fakeRepository(details(summary({ paymentMethod: 'cash_on_delivery', paymentStatus: 'pending_collection' }))));

    expect(screen.getByText('Payment')).toBeOnTheScreen();
    expect(screen.getByText('Cash on delivery')).toBeOnTheScreen();
    expect(screen.getByText('Pending collection')).toBeOnTheScreen();
  });

  it('an unknown-service order has no "Order again"', async () => {
    await renderScreen(fakeRepository(details(summary({ serviceId: 'unknown' }))));

    expect(screen.queryByText('Order again')).toBeNull();
  });

  it('shows a "no order selected" empty state for the bare route, without crashing', async () => {
    const repo = fakeRepository(null);
    await renderWithProviders(<TrackOrderScreen fetchDetails={repo.fetchDetails} watch={repo.watch} />);

    expect(screen.getByText('No order selected')).toBeOnTheScreen();
    expect(repo.fetchDetails).not.toHaveBeenCalled();
    expect(repo.watch).not.toHaveBeenCalled();
  });

  it('shows a not-found state when the order does not resolve', async () => {
    const repo = fakeRepository(null);
    await renderScreen(repo);

    expect(screen.getByText('Order not found')).toBeOnTheScreen();
    expect(repo.state.watchCallCount).toBe(0);
  });

  it('shows a retry action when the lookup fails, and retrying reloads', async () => {
    const repo = fakeRepository(details(summary()));
    repo.fetchDetails.mockRejectedValueOnce(new Error('boom: order lookup failed'));
    await renderScreen(repo);

    expect(screen.getByText('Order could not be loaded')).toBeOnTheScreen();
    await act(async () => {
      fireEvent.press(screen.getByText('Try again'));
    });

    expect(await screen.findByText('Jollof Feast')).toBeOnTheScreen();
    expect(repo.fetchDetails).toHaveBeenCalledTimes(2);
  });

  it('"Order again" fills the cart and opens it', async () => {
    const navigate = jest.fn();
    // A non-empty food basket into an empty cart: fills without asking.
    const basket: ReorderBasket = {
      kind: 'food',
      items: [{ menuItemId: 'm', restaurantId: 'r', restaurantName: 'Jollof Feast', name: 'Jollof Rice', unitPrice: 1000, imageUrl: '', quantity: 2 }],
      skippedNames: [],
    };
    const service = {
      loadBasket: jest.fn(async () => basket),
      wouldReplaceCart: jest.fn(() => false),
      fillCart: jest.fn(async () => AppRoutes.foodCart),
    };
    await renderScreen(fakeRepository(details(summary())), { orderAgainService: service as unknown as OrderAgainService, navigate });

    await act(async () => {
      fireEvent.press(screen.getByTestId('order-details-order-again'));
    });

    expect(navigate).toHaveBeenCalledWith(AppRoutes.foodCart);
    expect(service.loadBasket).toHaveBeenCalledWith(expect.objectContaining({ id: ORDER_ID, serviceId: 'food' }));
  });
});

describe('TrackOrderScreen live updates (issue #297)', () => {
  it('a watchOrder tick triggers a refetch and the UI reflects the new status', async () => {
    const repo = fakeRepository(details(summary({ status: 'preparing' })));
    await renderScreen(repo);

    expect(screen.getAllByText('Preparing')).toHaveLength(2);
    expect(repo.state.watchCallCount).toBe(1);
    expect(repo.state.lastReference).toEqual({ orderId: ORDER_ID, serviceId: 'food' });

    // Simulate the merchant moving the order forward server-side, then a
    // realtime event firing for it.
    repo.state.order = details(summary({ status: 'out_for_delivery' }));
    await act(async () => {
      repo.emitOrderChanged();
    });

    await waitFor(() => expect(screen.getAllByText('Out for delivery')).toHaveLength(2));
    // The pill no longer reads "Preparing", but the timeline still shows it
    // as a completed step.
    expect(screen.getAllByText('Preparing')).toHaveLength(1);
    // Still just the one subscription -- ticks reuse it.
    expect(repo.state.watchCallCount).toBe(1);
    expect(repo.state.watchStopped).toBe(false);
  });

  it('stops watching once a tick shows the order reached a final state', async () => {
    const repo = fakeRepository(details(summary({ status: 'out_for_delivery' })));
    await renderScreen(repo);
    expect(repo.state.watchCallCount).toBe(1);

    repo.state.order = details(summary({ status: 'delivered' }));
    await act(async () => {
      repo.emitOrderChanged();
    });

    await waitFor(() => expect(screen.getAllByText('Delivered')).toHaveLength(2));
    expect(repo.state.watchStopped).toBe(true);
  });

  it('the subscription is cancelled when the screen is unmounted', async () => {
    const repo = fakeRepository(details(summary()));
    const { unmount } = await renderScreen(repo);

    expect(repo.state.watchCallCount).toBe(1);
    expect(repo.state.watchStopped).toBe(false);

    await act(async () => {
      unmount();
    });

    expect(repo.state.watchStopped).toBe(true);
  });

  it('does not subscribe for an order already in a final state', async () => {
    const delivered = fakeRepository(details(summary({ status: 'delivered' })));
    const first = await renderScreen(delivered);
    expect(delivered.state.watchCallCount).toBe(0);
    await act(async () => {
      first.unmount();
    });

    const cancelled = fakeRepository(details(summary({ status: 'cancelled' })));
    await renderScreen(cancelled);
    expect(cancelled.state.watchCallCount).toBe(0);
  });
});
