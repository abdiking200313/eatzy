import { SessionResetRegistry } from './session-reset-registry';

describe('SessionResetRegistry', () => {
  it('runs every registered callback with the incoming owner id', () => {
    const registry = new SessionResetRegistry();
    const calls: (string | null)[][] = [[], []];
    registry.register((ownerId) => calls[0].push(ownerId));
    registry.register((ownerId) => calls[1].push(ownerId));

    registry.notifyAll('user-1');
    registry.notifyAll(null);

    expect(calls).toEqual([
      ['user-1', null],
      ['user-1', null],
    ]);
  });

  it('stops notifying a callback once its unregister function is called', () => {
    const registry = new SessionResetRegistry();
    const received: (string | null)[] = [];
    const unregister = registry.register((ownerId) => received.push(ownerId));

    registry.notifyAll('user-1');
    unregister();
    registry.notifyAll('user-2');

    expect(received).toEqual(['user-1']);
  });

  it('is not disturbed by a callback that registers or removes another callback during the same pass', () => {
    const registry = new SessionResetRegistry();
    const order: string[] = [];

    let unregisterLate: (() => void) | undefined;
    let registeredLate = false;
    registry.register(() => {
      order.push('first');
      // Registered mid-pass, once -- must not run until the *next* notifyAll.
      if (!registeredLate) {
        registeredLate = true;
        unregisterLate = registry.register(() => order.push('late'));
      }
    });
    registry.register(() => order.push('second'));

    registry.notifyAll('user-1');
    expect(order).toEqual(['first', 'second']);

    order.length = 0;
    registry.notifyAll('user-2');
    expect(order).toEqual(['first', 'second', 'late']);

    unregisterLate?.();
    order.length = 0;
    registry.notifyAll('user-3');
    expect(order).toEqual(['first', 'second']);
  });

  it('clearForTest removes every registered callback', () => {
    const registry = new SessionResetRegistry();
    const received: (string | null)[] = [];
    registry.register((ownerId) => received.push(ownerId));

    registry.clearForTest();
    registry.notifyAll('user-1');

    expect(received).toEqual([]);
  });
});
