/**
 * Ports `flutter_app/test/merchant_orders_controller_test.dart` (issue #408 /
 * P9-03) against the in-memory `FakeMerchantOrdersRepository`, including the
 * "illegal transition surfaces a clear error, not a silent no-op" case, plus
 * RN-only cases for the realtime `watch` and overlapping-load sequencing.
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { FakeMerchantOrdersRepository } from '@/test-utils/fake-merchant-orders-repository';

import { merchantOrderFromRow, type MerchantOrder } from './api/merchant-order';
import type { MerchantOrdersRepository } from './api/merchant-orders-repository';
import { OrderStatusTransitionError } from './api/order-status-transition-error';
import { MerchantOrdersController, ORDER_STATUS_FAILURE_MESSAGE, ORDERS_LOAD_FAILURE_MESSAGE } from './merchant-orders-controller';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function foodOrder(id: string, status = 'confirmed'): MerchantOrder {
  return merchantOrderFromRow(
    {
      id,
      status,
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
      food_order_items: [{ id: 1, item_name: 'Sambusa', quantity: 2, unit_price: 250 }],
    },
    'food',
  );
}

const confirmedOrder = foodOrder('order-1');

function controllerWith(repository: MerchantOrdersRepository) {
  return new MerchantOrdersController({ repository, vertical: 'food', storeId: 'store-1' });
}

let originalReporter: ErrorReporter;
let reportError: jest.Mock;

beforeEach(() => {
  originalReporter = ErrorReporting.instance;
  reportError = jest.fn();
  ErrorReporting.instance = { reportError };
});

afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

describe('load', () => {
  it('populates orders and hasLoaded on success', async () => {
    const controller = controllerWith(new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] }));

    expect(controller.hasLoaded).toBe(false);
    await controller.load();

    expect(controller.hasLoaded).toBe(true);
    expect(controller.orders).toEqual([confirmedOrder]);
    expect(controller.loadError).toBeNull();
  });

  it('hasLoaded is true with no orders yet', async () => {
    const controller = controllerWith(new FakeMerchantOrdersRepository());

    await controller.load();

    expect(controller.hasLoaded).toBe(true);
    expect(controller.orders).toEqual([]);
  });

  it('sets loadError on failure', async () => {
    const repository = new FakeMerchantOrdersRepository();
    repository.failureToThrow = new Error('network down');
    const controller = controllerWith(repository);

    await controller.load();

    expect(controller.loadError).toBe(ORDERS_LOAD_FAILURE_MESSAGE);
    expect(controller.orders).toEqual([]);
    expect(reportError).toHaveBeenCalledWith(repository.failureToThrow, expect.anything(), 'MerchantOrdersController.load');
  });

  it('RN-only: passes its vertical and store id to the repository', async () => {
    const repository = new FakeMerchantOrdersRepository();
    await controllerWith(repository).load();

    expect(repository.fetches).toEqual([{ vertical: 'food', storeId: 'store-1' }]);
  });

  it('RN-only: when loads overlap, only the latest result is applied', async () => {
    const resolvers: ((orders: MerchantOrder[]) => void)[] = [];
    const repository: MerchantOrdersRepository = {
      fetchOrders: () => new Promise((resolve) => resolvers.push(resolve)),
      advanceOrderStatus: () => Promise.reject(new Error('unused')),
      watchOrders: () => () => {},
    };
    const controller = controllerWith(repository);

    const first = controller.load();
    const second = controller.load();
    resolvers[1]([foodOrder('newer')]);
    await second;
    resolvers[0]([foodOrder('stale')]);
    await first;

    expect(controller.orders.map((order) => order.id)).toEqual(['newer']);
    expect(controller.isLoading).toBe(false);
  });
});

describe('advanceStatus', () => {
  it('accepting a confirmed order advances it to preparing', async () => {
    const controller = controllerWith(new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] }));
    await controller.load();

    const succeeded = await controller.advanceStatus(confirmedOrder, 'preparing');

    expect(succeeded).toBe(true);
    expect(controller.orders[0].status).toBe('preparing');
    expect(controller.saveError).toBeNull();
  });

  it('rejecting a confirmed order cancels it', async () => {
    const controller = controllerWith(new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] }));
    await controller.load();

    const succeeded = await controller.advanceStatus(confirmedOrder, 'cancelled');

    expect(succeeded).toBe(true);
    expect(controller.orders[0].status).toBe('cancelled');
  });

  it('an illegal transition fails with a clear error, not a silent no-op', async () => {
    const controller = controllerWith(new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] }));
    await controller.load();

    // confirmed -> out_for_delivery skips the required "preparing" step.
    const succeeded = await controller.advanceStatus(confirmedOrder, 'out_for_delivery');

    expect(succeeded).toBe(false);
    expect(controller.saveError).toContain('Illegal food order status transition');
    // The order's status must not have changed on a rejected transition.
    expect(controller.orders[0].status).toBe('confirmed');
  });

  it('surfaces a generic message for a non-transition error', async () => {
    const repository = new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] });
    const controller = controllerWith(repository);
    await controller.load();
    repository.failureToThrow = new Error('network down');

    const succeeded = await controller.advanceStatus(confirmedOrder, 'preparing');

    expect(succeeded).toBe(false);
    expect(controller.saveError).toBe(ORDER_STATUS_FAILURE_MESSAGE);
    expect(controller.isSaving).toBe(false);
  });
});

describe('orderById', () => {
  it('returns null once loaded orders no longer contain the id', async () => {
    const controller = controllerWith(new FakeMerchantOrdersRepository());
    await controller.load();

    expect(controller.orderById('missing')).toBeNull();
  });

  it('RN-only: returns the current copy of a loaded order', async () => {
    const controller = controllerWith(new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] }));
    await controller.load();
    await controller.advanceStatus(confirmedOrder, 'preparing');

    expect(controller.orderById('order-1')?.status).toBe('preparing');
  });
});

it('OrderStatusTransitionError.toString returns the raw message', () => {
  const error = new OrderStatusTransitionError('boom');
  expect(error.toString()).toBe('boom');
  expect(error.message).toBe('boom');
});

describe('watch (RN-only realtime)', () => {
  it('a realtime change reloads, so a new customer order appears without a refresh', async () => {
    const repository = new FakeMerchantOrdersRepository({ initialOrders: [confirmedOrder] });
    const controller = controllerWith(repository);
    await controller.load();
    const listener = jest.fn();
    controller.subscribe(listener);

    const stop = controller.watch();
    expect([...repository.watchers][0].input).toEqual({ vertical: 'food', storeId: 'store-1' });

    repository.emitChange(foodOrder('order-2'));
    await new Promise<void>((resolve) => setImmediate(() => resolve()));

    expect(controller.orders.map((order) => order.id)).toEqual(['order-2', 'order-1']);
    expect(listener).toHaveBeenCalled();

    stop();
    expect(repository.watchers.size).toBe(0);
  });
});
