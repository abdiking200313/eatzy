/**
 * Ports `flutter_app/test/merchant_session_gate_test.dart`'s
 * `MerchantSessionGate.resolveFor` group (issue #363). The `AppRouter.
 * redirectFor`/widget-level groups in that same Flutter file are instead
 * covered at this app's own layout level by `src/merchant-redirect.test.tsx`
 * (there is no RN equivalent of GoRouter's async `redirect` callback to
 * port those groups against directly -- see that file's top comment).
 *
 * Each case builds its own isolated gate via `createMerchantSessionGate`
 * (a fresh `SessionResetRegistry`, never the shared `sessionResetRegistry`
 * singleton) so tests cannot see each other's state.
 */
import { createMerchantSessionGate, type RoleLookup } from './merchant-session-gate';
import { SessionResetRegistry } from './session-reset-registry';

// `merchant-session-gate.ts` imports `merchant-role-service.ts`, which in
// turn imports the real `@/platform/supabase/client` as its *default*
// `MerchantRoleService` dependency -- unused here since every case below
// passes its own fake `roleService`, but the module-level import still
// needs a stub (see `merchant-role-service.test.ts`'s own top comment).
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

/** Flushes both the microtask queue and one macrotask tick -- enough for `withTimeout`'s `Promise.race` plus the fire-and-forget `resolveFor` call a `SessionResetRegistry` callback makes to fully settle. */
function flushAsync(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

/** Answers `fetchRole` with `role`, optionally holding the answer back until `gate` resolves -- lets a test observe state while a lookup is still in flight. */
function fakeRoleService(
  role: string | null,
  options: { gate?: Promise<void> } = {},
): RoleLookup & { calls: number } {
  const service = {
    calls: 0,
    async fetchRole(_userId: string): Promise<string | null> {
      service.calls++;
      if (options.gate) {
        await options.gate;
      }
      return role;
    },
  };
  return service;
}

describe('createMerchantSessionGate / resolveFor', () => {
  test('caches a merchant and an admin role', async () => {
    const gate = createMerchantSessionGate({ registry: new SessionResetRegistry() });

    await gate.resolveFor('m-1', { roleService: fakeRoleService('merchant') });
    expect(gate.store.getState()).toEqual({
      resolvedUserId: 'm-1',
      isMerchantRole: true,
      isAdmin: false,
    });

    gate.reset();
    await gate.resolveFor('a-1', { roleService: fakeRoleService('admin') });
    expect(gate.store.getState()).toEqual({
      resolvedUserId: 'a-1',
      isMerchantRole: true,
      isAdmin: true,
    });
  });

  test('a customer or failed (null) lookup resolves as a plain customer', async () => {
    const gate = createMerchantSessionGate({ registry: new SessionResetRegistry() });

    await gate.resolveFor('c-1', { roleService: fakeRoleService('customer') });
    expect(gate.store.getState()).toEqual({
      resolvedUserId: 'c-1',
      isMerchantRole: false,
      isAdmin: false,
    });

    gate.reset();
    await gate.resolveFor('c-2', { roleService: fakeRoleService(null) });
    expect(gate.store.getState()).toEqual({
      resolvedUserId: 'c-2',
      isMerchantRole: false,
      isAdmin: false,
    });
  });

  test('does not look the same user up twice', async () => {
    const gate = createMerchantSessionGate({ registry: new SessionResetRegistry() });
    const service = fakeRoleService('merchant');

    await gate.resolveFor('m-1', { roleService: service });
    await gate.resolveFor('m-1', { roleService: service });

    expect(service.calls).toBe(1);
  });

  test('concurrent callers share one in-flight lookup', async () => {
    const gate = createMerchantSessionGate({ registry: new SessionResetRegistry() });
    let release!: () => void;
    const gatePromise = new Promise<void>((resolve) => {
      release = resolve;
    });
    const service = fakeRoleService('merchant', { gate: gatePromise });

    const first = gate.resolveFor('m-1', { roleService: service });
    const second = gate.resolveFor('m-1', { roleService: service });
    release();
    await Promise.all([first, second]);

    expect(service.calls).toBe(1);
    expect(gate.store.getState().isMerchantRole).toBe(true);
  });

  test('a different user is looked up again', async () => {
    const gate = createMerchantSessionGate({ registry: new SessionResetRegistry() });

    await gate.resolveFor('m-1', { roleService: fakeRoleService('merchant') });
    await gate.resolveFor('c-1', { roleService: fakeRoleService('customer') });

    expect(gate.store.getState()).toEqual({
      resolvedUserId: 'c-1',
      isMerchantRole: false,
      isAdmin: false,
    });
  });

  test('a lookup finishing after reset (sign-out) cannot repopulate the gate', async () => {
    const gate = createMerchantSessionGate({ registry: new SessionResetRegistry() });
    let release!: () => void;
    const gatePromise = new Promise<void>((resolve) => {
      release = resolve;
    });

    const pending = gate.resolveFor('m-1', { roleService: fakeRoleService('admin', { gate: gatePromise }) });

    gate.reset(); // signed out while the lookup is running
    release();
    await pending;

    expect(gate.store.getState()).toEqual({
      resolvedUserId: null,
      isMerchantRole: false,
      isAdmin: false,
    });
  });
});

describe('createMerchantSessionGate / SessionResetRegistry wiring', () => {
  test('an account change (non-null owner) starts a role lookup for the new owner', async () => {
    const registry = new SessionResetRegistry();
    const roleService = fakeRoleService('merchant');
    const gate = createMerchantSessionGate({ registry, roleService });

    registry.notifyAll('m-1');
    // The lookup is fired-and-forgotten by the registry callback -- flush
    // async work so its promise settles before asserting.
    await flushAsync();

    expect(roleService.calls).toBe(1);
    expect(gate.store.getState()).toEqual({
      resolvedUserId: 'm-1',
      isMerchantRole: true,
      isAdmin: false,
    });
  });

  test('sign-out (null owner) resets the gate', async () => {
    const registry = new SessionResetRegistry();
    const gate = createMerchantSessionGate({ registry, roleService: fakeRoleService('merchant') });

    registry.notifyAll('m-1');
    await flushAsync();
    expect(gate.store.getState().isMerchantRole).toBe(true);

    registry.notifyAll(null);

    expect(gate.store.getState()).toEqual({
      resolvedUserId: null,
      isMerchantRole: false,
      isAdmin: false,
    });
  });

  test('unregister stops the gate from reacting to further account changes', async () => {
    const registry = new SessionResetRegistry();
    const roleService = fakeRoleService('merchant');
    const gate = createMerchantSessionGate({ registry, roleService });

    gate.unregister();
    registry.notifyAll('m-1');
    await flushAsync();

    expect(roleService.calls).toBe(0);
    expect(gate.store.getState().resolvedUserId).toBeNull();
  });
});
