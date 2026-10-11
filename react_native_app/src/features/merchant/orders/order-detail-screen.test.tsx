/**
 * Ports `flutter_app/test/order_detail_screen_test.dart` (issue #409 /
 * P9-04): `OrderDetailScreen` driven directly with an injected, already
 * loaded `MerchantOrdersController`, covering a vertical's status vocabulary
 * and the terminal state. The Dart `find.widgetWithText(FilledButton, ...)`
 * / `OutlinedButton` become the `order-detail-advance` /
 * `order-detail-cancel` test ids plus their label.
 *
 * RN-only cases cover the per-vertical delivery/payment details, the
 * server-rejection snackbar, and the self-resolving (route / deep-link)
 * path the Dart test reaches only through `orders_screen_test.dart`.
 */
import { act, fireEvent, render, screen } from '@testing-library/react-native';

import { FakeMerchantOrdersRepository } from '@/test-utils/fake-merchant-orders-repository';
import { FakeMerchantStoreRepository } from '@/test-utils/fake-merchant-store-repository';

import type { MerchantStore } from '../store/api/merchant-store';
import { MerchantStoreController } from '../store/merchant-store-controller';
import { merchantOrderFromRow, type MerchantOrder } from './api/merchant-order';
import { OrderStatusTransitionError } from './api/order-status-transition-error';
import { MerchantOrdersController } from './merchant-orders-controller';
import { formatDateTime, OrderDetailScreen, paymentMethodLabel, paymentStatusLabel } from './order-detail-screen';

jest.mock('expo-router', () => ({ router: { push: jest.fn(), back: jest.fn(), canGoBack: jest.fn(() => true) } }));
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));

function orderWithStatus(status: string): MerchantOrder {
  return merchantOrderFromRow(
    {
      id: 'order-1',
      status,
      created_at: '2026-09-01T12:00:00Z',
      subtotal: 500,
      delivery_fee: 499,
      tax: 50,
      total: 1049,
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

async function loadedController(orders: MerchantOrder[], repository = new FakeMerchantOrdersRepository({ initialOrders: orders })) {
  const controller = new MerchantOrdersController({ repository, vertical: orders[0]?.vertical ?? 'food', storeId: 'store-1' });
  await controller.load();
  return { controller, repository };
}

function advanceButton() {
  return screen.queryByTestId('order-detail-advance');
}
function cancelButton() {
  return screen.queryByTestId('order-detail-cancel');
}

describe('OrderDetailScreen (order_detail_screen_test.dart)', () => {
  it('a confirmed order offers accept and reject', async () => {
    const { controller } = await loadedController([orderWithStatus('confirmed')]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    expect(advanceButton()?.props.accessibilityLabel).toBe('Accept order');
    expect(cancelButton()?.props.accessibilityLabel).toBe('Reject order');
  });

  it('rejecting a confirmed order cancels it', async () => {
    const { controller } = await loadedController([orderWithStatus('confirmed')]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    await fireEvent.press(screen.getByRole('button', { name: 'Reject order' }));

    expect(controller.orders[0].status).toBe('cancelled');
    expect(screen.getAllByText('Cancelled').length).toBeGreaterThan(0);
    // A cancelled order is terminal -- no further actions offered.
    expect(screen.queryByRole('button', { name: 'Accept order' })).toBeNull();
  });

  it('a preparing order offers "mark as out for delivery" and cancel', async () => {
    const { controller } = await loadedController([orderWithStatus('preparing')]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    expect(advanceButton()?.props.accessibilityLabel).toBe('Mark as Out for delivery');
    expect(cancelButton()?.props.accessibilityLabel).toBe('Cancel order');

    await fireEvent.press(screen.getByRole('button', { name: 'Mark as Out for delivery' }));

    expect(controller.orders[0].status).toBe('out_for_delivery');
  });

  it('out for delivery can only be marked delivered, not cancelled', async () => {
    const { controller } = await loadedController([orderWithStatus('out_for_delivery')]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    expect(advanceButton()?.props.accessibilityLabel).toBe('Mark as Delivered');
    expect(cancelButton()).toBeNull();

    await fireEvent.press(screen.getByRole('button', { name: 'Mark as Delivered' }));

    expect(controller.orders[0].status).toBe('delivered');
  });

  it('a delivered order offers no further actions', async () => {
    const { controller } = await loadedController([orderWithStatus('delivered')]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    expect(screen.getByText('This order is complete. No further action is available.')).toBeTruthy();
    expect(advanceButton()).toBeNull();
    expect(cancelButton()).toBeNull();
  });

  it('shows a fallback when the order is no longer available', async () => {
    const { controller } = await loadedController([]);
    await render(<OrderDetailScreen controller={controller} orderId="missing" />);

    expect(screen.getByText('This order is no longer available.')).toBeTruthy();
  });
});

describe('OrderDetailScreen (RN-only cases)', () => {
  it('shows items, totals in dollars, delivery and payment details', async () => {
    const order = merchantOrderFromRow(
      {
        ...rowFor('confirmed'),
        payment_method: 'cash_on_delivery',
        payment_status: 'pending_collection',
      },
      'food',
    );
    const { controller } = await loadedController([order]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    expect(screen.getByText('Order #order-1')).toBeTruthy();
    expect(screen.getByText('2x')).toBeTruthy();
    expect(screen.getByText('Sambusa')).toBeTruthy();
    expect(screen.getAllByText('$5.00')).toHaveLength(2); // line total + subtotal
    expect(screen.getByText('$4.99')).toBeTruthy();
    expect(screen.getByText('Tax')).toBeTruthy();
    expect(screen.getByText('$10.49')).toBeTruthy();
    expect(screen.getByText('Amina')).toBeTruthy();
    expect(screen.getByText('+252-61-000-0000')).toBeTruthy();
    expect(screen.getByText('Main St, Hodan, Mogadishu')).toBeTruthy();
    expect(screen.getByText('Cash on delivery')).toBeTruthy();
    expect(screen.getByText('Pending collection')).toBeTruthy();
  });

  it('grocery shows its window and substitution preference, no tax; an empty note shows the call hint', async () => {
    const order = merchantOrderFromRow(
      {
        id: 'order-g',
        status: 'shopping',
        created_at: '2026-09-01T12:00:00Z',
        subtotal: 800,
        delivery_fee: 250,
        total: 1050,
        recipient_name: 'Farah',
        phone: '1',
        street: '',
        district: '',
        city: '',
        delivery_slot_label: 'Today 4-6pm',
        substitution_preference: 'contact_me',
        grocery_order_items: [{ id: 1, product_name: 'Bananas', quantity: 2.5, unit_price: 100 }],
      },
      'grocery',
    );
    const { controller } = await loadedController([order]);
    await render(<OrderDetailScreen controller={controller} orderId="order-g" />);

    expect(screen.getByText('2.5x')).toBeTruthy();
    expect(screen.getByText('Delivery window: Today 4-6pm')).toBeTruthy();
    expect(screen.getByText('Contact me before substituting')).toBeTruthy();
    expect(screen.getByText('No delivery note. Call the customer for directions.')).toBeTruthy();
    expect(screen.queryByText('Tax')).toBeNull();
    expect(screen.queryByText('Payment')).toBeNull();
    expect(advanceButton()?.props.accessibilityLabel).toBe('Mark as Out for delivery');
    expect(cancelButton()?.props.accessibilityLabel).toBe('Cancel order');
  });

  it('pharmacy shows its delivery instructions and accepts into packing', async () => {
    const order = merchantOrderFromRow(
      { ...rowFor('confirmed'), id: 'order-p', delivery_instructions: 'Leave with the gate guard', pharmacy_order_items: [] },
      'pharmacy',
    );
    const { controller, repository } = await loadedController([order]);
    const advance = jest.spyOn(repository, 'advanceOrderStatus');
    await render(<OrderDetailScreen controller={controller} orderId="order-p" />);

    expect(screen.getByText('Instructions: Leave with the gate guard')).toBeTruthy();
    await fireEvent.press(screen.getByRole('button', { name: 'Accept order' }));

    expect(advance).toHaveBeenCalledWith({ vertical: 'pharmacy', orderId: 'order-p', newStatus: 'packing' });
    expect(await screen.findByText('Order marked as Packing.')).toBeTruthy();
  });

  it("a server rejection shows the RPC's message and leaves the status unchanged", async () => {
    const { controller, repository } = await loadedController([orderWithStatus('confirmed')]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    repository.failureToThrow = new OrderStatusTransitionError('Illegal food order status transition: confirmed -> preparing');
    await fireEvent.press(screen.getByRole('button', { name: 'Accept order' }));

    expect(await screen.findByText('Illegal food order status transition: confirmed -> preparing')).toBeTruthy();
    expect(screen.getByText('Confirmed')).toBeTruthy();
  });

  it('a non-transition failure shows the generic message', async () => {
    const { controller, repository } = await loadedController([orderWithStatus('confirmed')]);
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    repository.failureToThrow = new Error('network down');
    await fireEvent.press(screen.getByRole('button', { name: 'Reject order' }));

    expect(await screen.findByText('The order status could not be updated. Please try again.')).toBeTruthy();
  });

  it('disables both actions while a change is saving', async () => {
    const { controller, repository } = await loadedController([orderWithStatus('confirmed')]);
    let release!: () => void;
    jest.spyOn(repository, 'advanceOrderStatus').mockImplementation(
      () => new Promise<string>((resolve) => (release = () => resolve('preparing'))),
    );
    await render(<OrderDetailScreen controller={controller} orderId="order-1" />);

    await fireEvent.press(screen.getByRole('button', { name: 'Accept order' }));

    expect(advanceButton()?.props.accessibilityState).toMatchObject({ disabled: true, busy: true });
    expect(cancelButton()?.props.accessibilityState).toMatchObject({ disabled: true });

    await act(async () => release());
    expect(advanceButton()?.props.accessibilityLabel).toBe('Mark as Out for delivery');
  });

  describe('self-resolving (route / deep link)', () => {
    const store: MerchantStore = {
      id: 'store-1',
      vertical: 'food',
      name: 'Zivo Diner',
      location: 'Hodan, Mogadishu',
      isOpen: true,
      description: null,
      imageUrl: null,
    };

    it("resolves the merchant's store, loads its orders, and watches for realtime changes", async () => {
      const storeController = new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore: store }) });
      const ordersRepository = new FakeMerchantOrdersRepository({ initialOrders: [orderWithStatus('confirmed')] });
      const { unmount } = await render(
        <OrderDetailScreen orderId="order-1" ownerId="merchant-1" storeController={storeController} ordersRepository={ordersRepository} />,
      );

      expect(await screen.findByRole('button', { name: 'Accept order' })).toBeTruthy();
      expect(ordersRepository.fetches).toEqual([{ vertical: 'food', storeId: 'store-1' }]);
      expect(ordersRepository.watchers.size).toBe(1);

      // A change made elsewhere arrives over realtime.
      ordersRepository.orders = [orderWithStatus('cancelled')];
      await act(async () => ordersRepository.emitChange());
      expect(await screen.findByText(/complete\. No further action/)).toBeTruthy();

      await unmount();
      expect(ordersRepository.watchers.size).toBe(0);
    });

    it('shows the fallback once the store lookup finds no store', async () => {
      const storeController = new MerchantStoreController({ repository: new FakeMerchantStoreRepository({ initialStore: null }) });
      await render(
        <OrderDetailScreen
          orderId="order-1"
          ownerId="merchant-1"
          storeController={storeController}
          ordersRepository={new FakeMerchantOrdersRepository()}
        />,
      );

      expect(await screen.findByText('This order is no longer available.')).toBeTruthy();
    });

    it('shows the fallback when signed out', async () => {
      await render(<OrderDetailScreen orderId="order-1" ownerId={null} ordersRepository={new FakeMerchantOrdersRepository()} />);

      expect(screen.getByText('This order is no longer available.')).toBeTruthy();
    });

    it('offers a retry when the store cannot be loaded', async () => {
      const storeRepository = new FakeMerchantStoreRepository({ initialStore: store });
      storeRepository.failureToThrow = new Error('down');
      await render(
        <OrderDetailScreen
          orderId="order-1"
          ownerId="merchant-1"
          storeController={new MerchantStoreController({ repository: storeRepository })}
          ordersRepository={new FakeMerchantOrdersRepository({ initialOrders: [orderWithStatus('confirmed')] })}
        />,
      );

      expect(await screen.findByText('Your store could not be loaded. Please try again.')).toBeTruthy();
      storeRepository.failureToThrow = null;
      await fireEvent.press(screen.getByRole('button', { name: 'Try again' }));

      expect(await screen.findByRole('button', { name: 'Accept order' })).toBeTruthy();
    });
  });

  it('label helpers fall back to the raw value; dates render as local yyyy-MM-dd HH:mm', () => {
    expect(paymentMethodLabel('card')).toBe('card');
    expect(paymentStatusLabel('collected')).toBe('Collected');
    expect(paymentStatusLabel('refunded')).toBe('Refunded');
    expect(paymentStatusLabel('other')).toBe('other');
    expect(formatDateTime(new Date(2026, 0, 5, 9, 7))).toBe('2026-01-05 09:07');
  });
});

function rowFor(status: string): Record<string, unknown> {
  return {
    id: 'order-1',
    status,
    created_at: '2026-09-01T12:00:00Z',
    subtotal: 500,
    delivery_fee: 499,
    tax: 50,
    total: 1049,
    recipient_name: 'Amina',
    phone: '+252-61-000-0000',
    street: 'Main St',
    district: 'Hodan',
    city: 'Mogadishu',
    food_order_items: [{ id: 1, item_name: 'Sambusa', quantity: 2, unit_price: 250 }],
  };
}
