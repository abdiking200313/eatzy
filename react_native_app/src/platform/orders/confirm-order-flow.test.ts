// Ports the `confirmDemoOrder` group from
// flutter_app/test/checkout_screens_test.dart: the shared "validate, place a
// demo order, record activity, clear the cart" orchestration, exercised
// directly rather than through any vertical's `CheckoutScreen`. TypeScript's
// `onSaveFailed` has no separate stack-trace parameter (see this file's own
// doc comment), so the Dart "passes the thrown error and stack trace"
// case is ported as just the error.
import { confirmDemoOrder } from './confirm-order-flow';

describe('confirmDemoOrder', () => {
  it('runs placeOrder -> recordActivity -> clearCart -> onConfirmed, in order, on the happy path', async () => {
    const calls: string[] = [];

    const result = await confirmDemoOrder<string, boolean, string>({
      validation: true,
      isValid: (validation) => validation,
      onInvalid: () => 'invalid',
      placeOrder: async () => {
        calls.push('placeOrder');
        return 'order-1';
      },
      fallbackOrder: () => 'fallback-order',
      onSaveFailed: () => 'save-failed',
      recordActivity: (order) => {
        expect(order).toBe('order-1');
        calls.push('recordActivity');
      },
      clearCart: () => {
        calls.push('clearCart');
      },
      onConfirmed: (order) => {
        calls.push('onConfirmed');
        return `confirmed:${order}`;
      },
    });

    expect(result).toBe('confirmed:order-1');
    expect(calls).toEqual(['placeOrder', 'recordActivity', 'clearCart', 'onConfirmed']);
  });

  it('returns onInvalid without ever calling placeOrder when validation fails', async () => {
    const placeOrder = jest.fn(async () => 'order-1');
    const recordActivity = jest.fn();
    const clearCart = jest.fn();

    const result = await confirmDemoOrder<string, boolean, string>({
      validation: false,
      isValid: (validation) => validation,
      onInvalid: (validation) => {
        expect(validation).toBe(false);
        return 'invalid';
      },
      placeOrder,
      fallbackOrder: () => 'fallback-order',
      onSaveFailed: () => 'save-failed',
      recordActivity,
      clearCart,
      onConfirmed: jest.fn(),
    });

    expect(result).toBe('invalid');
    expect(placeOrder).not.toHaveBeenCalled();
    expect(recordActivity).not.toHaveBeenCalled();
    expect(clearCart).not.toHaveBeenCalled();
  });

  it.each([null, undefined])(
    'falls back to fallbackOrder() when placeOrder resolves to %s',
    async (resolved) => {
      const recordActivity = jest.fn();

      const result = await confirmDemoOrder<string, boolean, string>({
        validation: true,
        isValid: (validation) => validation,
        onInvalid: () => 'invalid',
        placeOrder: async () => resolved,
        fallbackOrder: () => 'fallback-order',
        onSaveFailed: () => 'save-failed',
        recordActivity,
        clearCart: () => {},
        onConfirmed: (order) => `confirmed:${order}`,
      });

      expect(result).toBe('confirmed:fallback-order');
      expect(recordActivity).toHaveBeenCalledWith('fallback-order');
    },
  );

  it('routes a thrown placeOrder error to onSaveFailed without recording activity or clearing the cart', async () => {
    const thrown = new Error('boom');
    const recordActivity = jest.fn();
    const clearCart = jest.fn();
    const onConfirmed = jest.fn();

    const result = await confirmDemoOrder<string, boolean, string>({
      validation: true,
      isValid: (validation) => validation,
      onInvalid: () => 'invalid',
      placeOrder: async () => {
        throw thrown;
      },
      fallbackOrder: () => 'fallback-order',
      onSaveFailed: (error) => {
        expect(error).toBe(thrown);
        return 'save-failed';
      },
      recordActivity,
      clearCart,
      onConfirmed,
    });

    expect(result).toBe('save-failed');
    expect(recordActivity).not.toHaveBeenCalled();
    expect(clearCart).not.toHaveBeenCalled();
    expect(onConfirmed).not.toHaveBeenCalled();
  });

  it('awaits an async clearCart before onConfirmed runs', async () => {
    const calls: string[] = [];

    const result = await confirmDemoOrder<string, boolean, string>({
      validation: true,
      isValid: (validation) => validation,
      onInvalid: () => 'invalid',
      placeOrder: async () => 'order-1',
      fallbackOrder: () => 'fallback-order',
      onSaveFailed: () => 'save-failed',
      recordActivity: () => {
        calls.push('recordActivity');
      },
      // Resolves on a later microtask/macrotask than a synchronous
      // `clearCart` would -- if `confirmDemoOrder` ever stopped awaiting
      // this (e.g. called it without `await`), `onConfirmed` would run
      // before 'clearCart' lands in `calls`.
      clearCart: () =>
        new Promise<void>((resolve) => {
          setTimeout(() => {
            calls.push('clearCart');
            resolve();
          }, 0);
        }),
      onConfirmed: (order) => {
        calls.push('onConfirmed');
        return `confirmed:${order}`;
      },
    });

    expect(result).toBe('confirmed:order-1');
    expect(calls).toEqual(['recordActivity', 'clearCart', 'onConfirmed']);
  });
});
