/**
 * Ports `flutter_app/test/orders_screen_test.dart` (issue #408 / P9-03): the
 * Orders screen's loading / no-store / empty / error / loaded states against
 * the in-memory fake repositories, plus RN-only realtime cases (the issue's
 * "a new customer order appears without a refresh" acceptance criterion).
 *
 * The Dart `find.byType(CircularProgressIndicator)` becomes the shared
 * `LoadingState`'s `testID`; the `RefreshIndicator` fling becomes calling the
 * list's `refreshControl.onRefresh` directly (as `activity.test.tsx` does).
 *
 * The Dart file's last two cases ("tapping an order opens detail and
 * accepting it advances it", "a rejected transition shows a clear error
 * banner") drive the order detail screen through a real `GoRouter`. Here
 * `OrdersHarness` stands in for the expo-router stack: the list's
 * `onOpenOrder` pushes `OrderDetailScreen` on top (self-resolving from the
 * same store controller + orders repository, as the
 * `/merchant/orders/:orderId` route does), and "back" pops it. The
 * default tap -> `router.push('/merchant/orders/:id')` wiring is covered
 * separately below. Dart reloads the list on pop; in RN the list stays
 * mounted and the realtime UPDATE event the RPC's write produces refreshes
 * it, simulated with `emitChange()`.
 */
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import { FakeMerchantOrdersRepository } from '@/test-utils/fake-merchant-orders-repository';
import { FakeMerchantStoreRepository } from '@/test-utils/fake-merchant-store-repository';

import type { MerchantStore } from '../store/api/merchant-store';
import type { MerchantStoreRepository } from '../store/api/merchant-store-repository';
import { MerchantStoreController } from '../store/merchant-store-controller';
import { merchantOrderFromRow, type MerchantOrder } from './api/merchant-order';
import type { MerchantOrdersRepository } from './api/merchant-orders-repository';
import { OrderStatusTransitionError } from './api/order-status-transition-error';
import { OrderDetailScreen } from './order-detail-screen';
import { OrdersScreen } from './orders-screen';

jest.mock('expo-router', () => ({ router: { push: jest.fn(), back: jest.fn(), canGoBack: jest.fn(() => true) } }));
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));

/** Mirrors the Dart `_NeverCompletingOrdersRepository`. */
class NeverCompletingOrdersRepository implements MerchantOrdersRepository {
  private resolve!: (orders: MerchantOrder[]) => void;
  private readonly pending = new Promise<MerchantOrder[]>((resolve) => {
    this.resolve = resolve;
  });

  complete(orders: MerchantOrder[]): void {
    this.resolve(orders);
  }
  fetchOrders(): Promise<MerchantOrder[]> {
    return this.pending;
  }
  advanceOrderStatus(): Promise<string> {
    throw new Error('unimplemented');
  }
  watchOrders(): () => void {
    return () => {};
  }
}

/** Mirrors the Dart `_NeverCompletingStoreRepository`. */
class NeverCompletingStoreRepository implements MerchantStoreRepository {
  private resolve!: (store: MerchantStore | null) => void;
  private readonly pending = new Promise<MerchantStore | null>((resolve) => {
    this.resolve = resolve;
  });

  complete(store: MerchantStore | null): void {
    this.resolve(store);
  }
  fetchOwnStore(): Promise<MerchantStore | null> {
    return this.pending;
  }
  createStore(): Promise<MerchantStore> {
    throw new Error('unimplemented');
  }
  updateStore(): Promise<MerchantStore> {
    throw new Error('unimplemented');
  }
}

const store: MerchantStore = {
  id: 'store-1',
  vertical: 'food',
  name: 'Zivo Diner',
  location: 'Hodan, Mogadishu',
  isOpen: true,
  description: null,
  imageUrl: null,
};

function foodOrder(id: string, status = 'confirmed', total = 1049): MerchantOrder {
  return merchantOrderFromRow(
    {
      id,
      status,
      created_at: '2026-09-01T12:00:00Z',
      subtotal: 500,
      delivery_fee: 499,
      tax: 50,
      total,
      recipient_name: 'Amina',
      phone: '+252-61-000-0000',
      street: 'Main St',
      district: 'Hodan',
      city: 'Mogadishu',
      food_order_items: [{ id: 1, item_name: 'Sambusa', quantity: 2, unit_price: 250 }],
    },
    'food',
  );
}

const confirmedOrder = foodOrder('order-1-abcdef');

function storeControllerWith(initialStore: MerchantStore | null) {
  return new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore }) });
}

beforeEach(() => {
  jest.clearAllMocks();
});

/**
 * Stand-in for the merchant stack (the Dart `buildOrdersApp`): the Orders
 * list underneath, with the detail route pushed on top when an order is
 * tapped. The list stays mounted while the detail is open, as in a stack.
 */
function OrdersHarness({ storeController, ordersRepository }: { storeController: MerchantStoreController; ordersRepository: MerchantOrdersRepository }) {
  const [openOrderId, setOpenOrderId] = useState<string | null>(null);
  return (
    <View style={{ flex: 1 }}>
      <View style={{ flex: 1, display: openOrderId == null ? 'flex' : 'none' }} testID="orders-route">
        <OrdersScreen ownerId="merchant-1" storeController={storeController} ordersRepository={ordersRepository} onOpenOrder={setOpenOrderId} />
      </View>
      {openOrderId != null && (
        <View style={{ flex: 1 }} testID="order-detail-route">
          <Pressable testID="pop-route" onPress={() => setOpenOrderId(null)}>
            <Text>Pop route</Text>
          </Pressable>
          <OrderDetailScreen orderId={openOrderId} ownerId="merchant-1" storeController={storeController} ordersRepository={ordersRepository} />
        </View>
      )}
    </View>
  );
}

describe('OrdersScreen (orders_screen_test.dart)', () => {
  it('shows a loading indicator while the store loads', async () => {
    const storeRepository = new NeverCompletingStoreRepository();
    await render(
      <OrdersScreen
        ownerId="merchant-1"
        storeController={new MerchantStoreController({ repository: storeRepository })}
        ordersRepository={new FakeMerchantOrdersRepository()}
      />,
    );

    expect(screen.getByTestId('loading-state')).toBeTruthy();

    await act(async () => storeRepository.complete(store));
    expect(await screen.findByText('No orders yet')).toBeTruthy();
  });

  it("shows a 'set up your store' state with no store", async () => {
    await render(<OrdersScreen ownerId="merchant-1" storeController={storeControllerWith(null)} ordersRepository={new FakeMerchantOrdersRepository()} />);

    expect(await screen.findByText('Set up your store first')).toBeTruthy();
  });

  it('shows a loading indicator while orders load', async () => {
    const ordersRepository = new NeverCompletingOrdersRepository();
    await render(<OrdersScreen ownerId="merchant-1" storeController={storeControllerWith(store)} ordersRepository={ordersRepository} />);

    expect(await screen.findByTestId('loading-state')).toBeTruthy();
    expect(await screen.findByText('Zivo Diner')).toBeTruthy();

    await act(async () => ordersRepository.complete([]));
    await waitFor(() => expect(screen.queryByTestId('loading-state')).toBeNull());
  });

  it('shows an empty state with no orders', async () => {
    await render(<OrdersScreen ownerId="merchant-1" storeController={storeControllerWith(store)} ordersRepository={new FakeMerchantOrdersRepository()} />);

    expect(await screen.findByText('No orders yet')).toBeTruthy();
  });

  it('shows an error state with retry when the load fails', async () => {
    const ordersRepository = new FakeMerchantOrdersRepository();
    ordersRepository.failureToThrow = new Error('boom');
    await render(<OrdersScreen ownerId="merchant-1" storeController={storeControllerWith(store)} ordersRepository={ordersRepository} />);

    expect(await screen.findByText('Your orders could not be loaded. Please try again.')).toBeTruthy();

    ordersRepository.failureToThrow = null;
    await fireEvent.press(screen.getByRole('button', { name: 'Try again' }));

    expect(await screen.findByText('No orders yet')).toBeTruthy();
  });

  it('lists an order and supports pull-to-refresh', async () => {
    const ordersRepository = new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] });
    await render(<OrdersScreen ownerId="merchant-1" storeController={storeControllerWith(store)} ordersRepository={ordersRepository} />);

    expect(await screen.findByText('Order #order-1-')).toBeTruthy();
    expect(screen.getByText('Confirmed')).toBeTruthy();

    const fetchesBefore = ordersRepository.fetches.length;
    await act(async () => {
      await screen.getByTestId('merchant-orders-list').props.refreshControl.props.onRefresh();
    });

    expect(ordersRepository.fetches.length).toBe(fetchesBefore + 1);
    expect(screen.getByText('Order #order-1-')).toBeTruthy();
  });

  it('tapping an order opens its detail route', async () => {
    await render(
      <OrdersScreen
        ownerId="merchant-1"
        storeController={storeControllerWith(store)}
        ordersRepository={new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] })}
      />,
    );

    await fireEvent.press(await screen.findByText('Order #order-1-'));

    expect(router.push).toHaveBeenCalledWith('/merchant/orders/order-1-abcdef');
  });
});

describe('OrdersScreen -> OrderDetailScreen (orders_screen_test.dart)', () => {
  it('tapping an order opens detail and accepting it advances it', async () => {
    const ordersRepository = new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] });
    await render(<OrdersHarness storeController={storeControllerWith(store)} ordersRepository={ordersRepository} />);

    await fireEvent.press(await screen.findByText('Order #order-1-'));

    // Navigation actually reached the order-detail route.
    expect(screen.getByTestId('order-detail-route')).toBeTruthy();
    // Line items and address/contact info are shown on the detail screen.
    expect(await screen.findByText('Sambusa')).toBeTruthy();
    expect(screen.getByText('Amina')).toBeTruthy();
    expect(screen.getByText(/Main St/)).toBeTruthy();

    await fireEvent.press(screen.getByRole('button', { name: 'Accept order' }));

    // The pill on the detail screen reflects the new status immediately.
    expect(screen.getAllByText('Preparing').length).toBeGreaterThan(0);

    // The Dart `tester.pageBack()`.
    await fireEvent.press(screen.getByTestId('pop-route'));
    // The RPC's UPDATE reaches the still-mounted list over realtime.
    await act(async () => ordersRepository.emitChange());

    expect(screen.queryByTestId('order-detail-route')).toBeNull();
    expect(await screen.findByText('Preparing')).toBeTruthy();
    expect(screen.queryByText('Confirmed')).toBeNull();
  });

  it('a rejected transition shows a clear error banner, not a silent no-op', async () => {
    const ordersRepository = new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] });
    await render(<OrdersHarness storeController={storeControllerWith(store)} ordersRepository={ordersRepository} />);

    await fireEvent.press(await screen.findByText('Order #order-1-'));
    expect(screen.getByTestId('order-detail-route')).toBeTruthy();
    await screen.findByRole('button', { name: 'Accept order' });

    // Set the failure only now, so the initial loads still succeed.
    ordersRepository.failureToThrow = new OrderStatusTransitionError('Illegal food order status transition: confirmed -> preparing');
    await fireEvent.press(screen.getByRole('button', { name: 'Accept order' }));

    expect(await screen.findByText('Illegal food order status transition: confirmed -> preparing')).toBeTruthy();
    // The status must not have silently changed.
    expect(screen.getAllByText('Confirmed').length).toBeGreaterThan(0);
  });
});

describe('OrdersScreen (RN-only cases)', () => {
  it('a new customer order appears without a refresh, and the subscription stops on unmount', async () => {
    const ordersRepository = new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] });
    const { unmount } = await render(
      <OrdersScreen ownerId="merchant-1" storeController={storeControllerWith(store)} ordersRepository={ordersRepository} />,
    );
    await screen.findByText('Order #order-1-');
    expect(ordersRepository.watchers.size).toBe(1);
    expect([...ordersRepository.watchers][0].input).toEqual({ vertical: 'food', storeId: 'store-1' });

    await act(async () => ordersRepository.emitChange(foodOrder('neworder-xyz')));

    expect(await screen.findByText('Order #neworder')).toBeTruthy();
    expect(screen.getByText('Order #order-1-')).toBeTruthy();
    // A realtime reload never shows the pull-to-refresh spinner.
    expect(screen.getByTestId('merchant-orders-list').props.refreshControl.props.refreshing).toBe(false);

    await unmount();
    expect(ordersRepository.watchers.size).toBe(0);
  });

  it('a status change pushed over realtime updates the pill', async () => {
    const ordersRepository = new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] });
    await render(<OrdersScreen ownerId="merchant-1" storeController={storeControllerWith(store)} ordersRepository={ordersRepository} />);
    await screen.findByText('Confirmed');

    ordersRepository.orders = [foodOrder('order-1-abcdef', 'cancelled')];
    await act(async () => ordersRepository.emitChange());

    expect(await screen.findByText('Cancelled')).toBeTruthy();
  });

  it('shows the items summary and total in dollars', async () => {
    await render(
      <OrdersScreen
        ownerId="merchant-1"
        storeController={storeControllerWith(store)}
        ordersRepository={new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] })}
      />,
    );

    expect(await screen.findByText('2x Sambusa')).toBeTruthy();
    expect(screen.getByText('$10.49')).toBeTruthy();
  });

  it('reuses an already-loaded shared store controller instead of refetching the store', async () => {
    const storeRepository = new FakeMerchantStoreRepository({ initialStore: store });
    const fetchOwnStore = jest.spyOn(storeRepository, 'fetchOwnStore');
    const storeController = new MerchantStoreController({ repository: storeRepository });
    await storeController.load('merchant-1');

    await render(<OrdersScreen ownerId="merchant-1" storeController={storeController} ordersRepository={new FakeMerchantOrdersRepository()} />);

    expect(await screen.findByText('No orders yet')).toBeTruthy();
    expect(fetchOwnStore).toHaveBeenCalledTimes(1);
  });

  it('shows the store error with retry when the store cannot be loaded', async () => {
    const storeRepository = new FakeMerchantStoreRepository({ initialStore: store });
    storeRepository.failureToThrow = new Error('down');
    await render(
      <OrdersScreen
        ownerId="merchant-1"
        storeController={new MerchantStoreController({ repository: storeRepository })}
        ordersRepository={new FakeMerchantOrdersRepository()}
      />,
    );

    expect(await screen.findByText('Your store could not be loaded. Please try again.')).toBeTruthy();

    storeRepository.failureToThrow = null;
    await fireEvent.press(screen.getByRole('button', { name: 'Try again' }));

    expect(await screen.findByText('No orders yet')).toBeTruthy();
  });
});
