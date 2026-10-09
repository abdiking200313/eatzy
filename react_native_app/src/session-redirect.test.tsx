/**
 * Integration-level coverage for issue #359's redirect gate: exercises the
 * real `src/app/(auth)/_layout.tsx` and `src/app/(app)/_layout.tsx` through
 * Expo Router's own `renderRouter`, with `@/stores/session-store` mocked so
 * each case can set `status`/`userId` directly. `src/platform/navigation/
 * redirect.test.ts` already covers every `resolveRedirect` case from
 * `app_router_test.dart` in isolation; this file instead checks that the
 * two layout components actually call it with the right inputs and act on
 * the result.
 *
 * See `route-reachability.test.tsx`'s top comment for why
 * `@/components/animated-icon`, `@/platform/supabase/client`, and
 * `@/platform/query/query-persistence` are mocked -- this file mounts the
 * same real root `_layout.tsx` and hits the same three issues.
 *
 * `@/stores/merchant-session-gate` (issue #363) is mocked too, for the same
 * reason `@/stores/session-store` is: both layouts under test now also read
 * it, and every case here cares only about the session-only rules, not the
 * merchant ones (those are `src/merchant-redirect.test.tsx`'s job) --
 * `setResolvedCustomer` below stands in for "the role lookup already
 * resolved this signed-in user as a plain customer", the state every case
 * that sets a signed-in session also needs so the layouts' `merchantRole
 * Pending` guard doesn't treat the role as still unresolved and skip their
 * redirect decision entirely.
 */
import { renderRouter, screen, waitFor } from 'expo-router/testing-library';

import { useMerchantSessionGateStore, type MerchantSessionGateState } from '@/stores/merchant-session-gate';
import { useSessionStore, type SessionState } from '@/stores/session-store';

jest.mock('@/components/animated-icon', () => ({ AnimatedSplashOverlay: () => null }));
jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));
jest.mock('@/stores/session-store', () => ({ useSessionStore: jest.fn() }));
jest.mock('@/stores/merchant-session-gate', () => ({ useMerchantSessionGateStore: jest.fn() }));
jest.mock('@/platform/query/query-persistence', () => ({
  queryPersistOptions: {
    persister: {
      persistClient: () => {},
      restoreClient: () => Promise.resolve(undefined),
      removeClient: () => Promise.resolve(undefined),
    },
    maxAge: 0,
    dehydrateOptions: { shouldDehydrateQuery: () => false },
  },
}));

const mockedUseSessionStore = useSessionStore as unknown as jest.Mock;
const mockedUseMerchantSessionGateStore = useMerchantSessionGateStore as unknown as jest.Mock;

function setSessionState(state: SessionState) {
  mockedUseSessionStore.mockImplementation((selector: (state: SessionState) => unknown) =>
    selector(state),
  );
}

function setMerchantGateState(state: MerchantSessionGateState) {
  mockedUseMerchantSessionGateStore.mockImplementation((selector: (state: MerchantSessionGateState) => unknown) =>
    selector(state),
  );
}

/** Stands in for "the role lookup already resolved `userId` as a plain customer" -- see this file's top comment. */
function setResolvedCustomer(userId: string) {
  setMerchantGateState({ resolvedUserId: userId, isMerchantRole: false, isAdmin: false });
}

async function renderRoute(path: string) {
  const result = renderRouter('src/app', { initialUrl: path });
  await result;
  return { result };
}

describe('session redirect gate ((auth)/_layout.tsx and (app)/_layout.tsx, issue #359)', () => {
  it('sends a signed-out visitor from a protected (app) route to /login', async () => {
    setSessionState({ status: 'signedOut', session: null, userId: null });

    const { result } = await renderRoute('/app');

    await waitFor(() => expect(result.getPathname()).toBe('/login'));
  });

  it('leaves a signed-out visitor on a public (auth) route', async () => {
    setSessionState({ status: 'signedOut', session: null, userId: null });

    await renderRoute('/welcome');

    // '/welcome' got real content in issue #364, so it no longer renders
    // the generic "<path> — not yet implemented" placeholder text the other
    // cases in this file check for.
    expect(await screen.findByText("See What's Open Near You")).toBeTruthy();
  });

  it('sends a signed-in user away from a signed-out-only route to /app', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'user-1' });
    setResolvedCustomer('user-1');

    const { result } = await renderRoute('/login');

    await waitFor(() => expect(result.getPathname()).toBe('/app'));
  });

  it('lets a signed-in user reach a protected (app) route', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'user-1' });
    setResolvedCustomer('user-1');

    await renderRoute('/support');

    expect(await screen.findByText('/support — not yet implemented')).toBeTruthy();
  });

  it('lets a signed-in user reach /reset-password (not a signed-out-only route)', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'user-1' });
    setResolvedCustomer('user-1');

    await renderRoute('/reset-password');

    // Real screen since issue #368 (previously the generic placeholder).
    expect(await screen.findByText('Set a new password')).toBeTruthy();
  });

  it('does not redirect yet while the session status is still loading', async () => {
    setSessionState({ status: 'loading', session: null, userId: null });

    await renderRoute('/app');

    expect(await screen.findByText('/app — not yet implemented')).toBeTruthy();
  });
});
