/**
 * Exercises the session store's wiring (issue #359): every auth event
 * updates the store's own state, and drives
 * {@link AccountStateCoordinator.handleOwnerChanged} so a registered reset
 * callback fires exactly when the signed-in owner actually changes -- see
 * `account-state-coordinator.test.ts` for the reset-registry behavior
 * itself.
 *
 * `session-store.ts` imports the real `@/platform/supabase/client` (its
 * default `auth` dependency, used only when a test doesn't inject its own)
 * and, at module load, eagerly constructs the app-wide singleton session
 * store -- see `route-reachability.test.tsx`'s top comment for why that
 * import needs a working `onAuthStateChange` stub under Jest rather than a
 * bare `{}`.
 */
import type { AuthChangeEvent, Session } from '@supabase/supabase-js';

import { createSessionStore, type AuthStateSource } from './session-store';
import { SessionResetRegistry } from './session-reset-registry';

jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));

function fakeSession(userId: string): Session {
  return { user: { id: userId } } as unknown as Session;
}

/** A fake {@link AuthStateSource} a test can fire events through directly. */
function createFakeAuthSource(): {
  source: AuthStateSource;
  emit: (event: AuthChangeEvent, session: Session | null) => void;
  isUnsubscribed: () => boolean;
} {
  let listener: ((event: AuthChangeEvent, session: Session | null) => void) | null = null;
  const state = { unsubscribed: false };

  const source: AuthStateSource = {
    onAuthStateChange(callback) {
      listener = callback;
      return {
        data: {
          subscription: {
            unsubscribe: () => {
              state.unsubscribed = true;
              listener = null;
            },
          },
        },
      };
    },
  };

  return {
    source,
    emit: (event, session) => listener?.(event, session),
    isUnsubscribed: () => state.unsubscribed,
  };
}

describe('createSessionStore', () => {
  it('starts in the loading status before any auth event arrives', () => {
    const { source } = createFakeAuthSource();
    const { store } = createSessionStore({ auth: source });

    expect(store.getState()).toEqual({ status: 'loading', session: null, userId: null });
  });

  it('moves to signedOut when the restored INITIAL_SESSION has no session', () => {
    const { source, emit } = createFakeAuthSource();
    const { store } = createSessionStore({ auth: source });

    emit('INITIAL_SESSION', null);

    expect(store.getState()).toEqual({ status: 'signedOut', session: null, userId: null });
  });

  it('moves to signedIn and resets registered state when a session arrives', () => {
    const registry = new SessionResetRegistry();
    const resetQueryCache = jest.fn();
    const seenOwners: (string | null)[] = [];
    registry.register((ownerId) => seenOwners.push(ownerId));

    const { source, emit } = createFakeAuthSource();
    const { store } = createSessionStore({
      auth: source,
      coordinatorOptions: { registry, resetQueryCache },
    });

    const session = fakeSession('user-1');
    emit('INITIAL_SESSION', session);

    expect(store.getState()).toEqual({ status: 'signedIn', session, userId: 'user-1' });
    expect(seenOwners).toEqual(['user-1']);
    expect(resetQueryCache).toHaveBeenCalledTimes(1);
  });

  it('does not re-run resets on a token refresh for the same signed-in user', () => {
    const registry = new SessionResetRegistry();
    const resetQueryCache = jest.fn();
    const seenOwners: (string | null)[] = [];
    registry.register((ownerId) => seenOwners.push(ownerId));

    const { source, emit } = createFakeAuthSource();
    const { store } = createSessionStore({
      auth: source,
      coordinatorOptions: { registry, resetQueryCache },
    });

    const firstSession = fakeSession('user-1');
    emit('INITIAL_SESSION', firstSession);

    const refreshedSession = fakeSession('user-1');
    emit('TOKEN_REFRESHED', refreshedSession);

    expect(store.getState()).toEqual({
      status: 'signedIn',
      session: refreshedSession,
      userId: 'user-1',
    });
    // Only the first (owner-changing) event triggered a reset.
    expect(seenOwners).toEqual(['user-1']);
    expect(resetQueryCache).toHaveBeenCalledTimes(1);
  });

  it('resets registered state again on sign-out, so no previous user data is left visible', () => {
    const registry = new SessionResetRegistry();
    const resetQueryCache = jest.fn();
    let cartItems: string[] = [];
    registry.register((ownerId) => {
      cartItems = ownerId === 'user-1' ? ['user-1 item'] : [];
    });

    const { source, emit } = createFakeAuthSource();
    const { store } = createSessionStore({
      auth: source,
      coordinatorOptions: { registry, resetQueryCache },
    });

    emit('INITIAL_SESSION', fakeSession('user-1'));
    expect(cartItems).toEqual(['user-1 item']);

    emit('SIGNED_OUT', null);

    expect(store.getState()).toEqual({ status: 'signedOut', session: null, userId: null });
    expect(cartItems).toEqual([]);
    expect(resetQueryCache).toHaveBeenCalledTimes(2);
  });

  it('resets again when a different user signs in on the same device', () => {
    const registry = new SessionResetRegistry();
    const seenOwners: (string | null)[] = [];
    registry.register((ownerId) => seenOwners.push(ownerId));

    const { source, emit } = createFakeAuthSource();
    const { store } = createSessionStore({ auth: source, coordinatorOptions: { registry } });

    emit('INITIAL_SESSION', fakeSession('user-1'));
    emit('SIGNED_OUT', null);
    emit('SIGNED_IN', fakeSession('user-2'));

    expect(store.getState().userId).toBe('user-2');
    expect(seenOwners).toEqual(['user-1', null, 'user-2']);
  });

  it('unsubscribe stops the store from reacting to further auth events', () => {
    const { source, emit, isUnsubscribed } = createFakeAuthSource();
    const { store, unsubscribe } = createSessionStore({ auth: source });

    unsubscribe();
    expect(isUnsubscribed()).toBe(true);

    emit('SIGNED_IN', fakeSession('user-1'));
    // The fake's own `emit` is a no-op once unsubscribed (no listener left),
    // so the store never saw the event.
    expect(store.getState().status).toBe('loading');
  });
});
