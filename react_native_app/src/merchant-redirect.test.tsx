/**
 * Layout-level coverage for issue #363's merchant-role gating: exercises
 * the real `src/app/(auth)/_layout.tsx`, `src/app/(app)/_layout.tsx` and
 * `src/app/merchant/_layout.tsx` through Expo Router's own `renderRouter`,
 * with `@/stores/session-store` and `@/stores/merchant-session-gate` both
 * mocked so each case can set session/role state directly -- the same
 * pattern `src/session-redirect.test.tsx` (issue #359) already uses for
 * the session-only cases. `src/platform/navigation/redirect.test.ts`
 * already covers every `resolveRedirect` merchant case (ported from
 * `app_router_test.dart`) in isolation, and `src/stores/merchant-session-
 * gate.test.ts` covers `resolveFor`'s own caching/dedup/reset-race
 * behavior (ported from `merchant_session_gate_test.dart`); this file
 * checks that the three layout components actually read the gate's state
 * and act on it the way Flutter's `AppRouter.redirectFor`/`MerchantShell`
 * do -- including the "role lookup still in flight" window neither
 * Flutter test file has a direct RN-`redirect`-callback equivalent for
 * (GoRouter's `redirect` can be awaited; Expo Router's layout redirect
 * cannot), so it is covered here at the render level instead: the role
 * being unresolved for the signed-in user must never let either a wrong
 * screen or the merchant shell itself flash past.
 *
 * See `route-reachability.test.tsx`'s top comment for why
 * `@/components/animated-icon`, `@/platform/supabase/client`, and
 * `@/platform/query/query-persistence` are mocked -- this file mounts the
 * same real root `_layout.tsx`.
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
  mockedUseSessionStore.mockImplementation((selector: (state: SessionState) => unknown) => selector(state));
}

function setMerchantGateState(state: MerchantSessionGateState) {
  mockedUseMerchantSessionGateStore.mockImplementation((selector: (state: MerchantSessionGateState) => unknown) =>
    selector(state),
  );
}

async function renderRoute(path: string) {
  const result = renderRouter('src/app', { initialUrl: path });
  await result;
  return { result };
}

describe('merchant-session gate (merchant/_layout.tsx, (auth)/_layout.tsx, (app)/_layout.tsx, issue #363)', () => {
  it('redirects a signed-in non-merchant away from /merchant to the main app', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'c-1' });
    setMerchantGateState({ resolvedUserId: 'c-1', isMerchantRole: false, isAdmin: false });

    const { result } = await renderRoute('/merchant');

    await waitFor(() => expect(result.getPathname()).toBe('/app'));
  });

  it('redirects a signed-out visitor hitting /merchant to /login, not the dashboard', async () => {
    setSessionState({ status: 'signedOut', session: null, userId: null });
    setMerchantGateState({ resolvedUserId: null, isMerchantRole: false, isAdmin: false });

    const { result } = await renderRoute('/merchant');

    await waitFor(() => expect(result.getPathname()).toBe('/login'));
  });

  it('lets a resolved merchant/admin reach the merchant dashboard', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'm-1' });
    setMerchantGateState({ resolvedUserId: 'm-1', isMerchantRole: true, isAdmin: false });

    await renderRoute('/merchant');

    expect(await screen.findByText('/merchant — not yet implemented')).toBeTruthy();
  });

  it('confines a signed-in merchant/admin anywhere outside /merchant to the dashboard', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'm-1' });
    setMerchantGateState({ resolvedUserId: 'm-1', isMerchantRole: true, isAdmin: false });

    const { result } = await renderRoute('/app');

    await waitFor(() => expect(result.getPathname()).toBe('/merchant'));
  });

  it('does not render the merchant shell nor redirect while the role lookup is still in flight for the current user', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'm-1' });
    // Not yet resolved for 'm-1' -- a lookup is presumed in flight.
    setMerchantGateState({ resolvedUserId: null, isMerchantRole: false, isAdmin: false });

    const { result } = await renderRoute('/merchant');

    expect(screen.queryByText('/merchant — not yet implemented')).toBeNull();
    expect(screen.queryByText('/app — not yet implemented')).toBeNull();
    expect(result.getPathname()).toBe('/merchant');
  });

  it('does not bounce a signed-in merchant/admin to the customer home while the role lookup is still in flight', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'm-1' });
    // Not yet resolved for 'm-1' -- without the pending guard, the
    // signed-out-only-route rule would otherwise send this straight to
    // /app before the role lookup can redirect it to /merchant instead.
    setMerchantGateState({ resolvedUserId: null, isMerchantRole: false, isAdmin: false });

    const { result } = await renderRoute('/login');

    expect(screen.queryByText('/app — not yet implemented')).toBeNull();
    expect(result.getPathname()).toBe('/login');
  });

  it('a signed-in plain customer is unaffected and reaches ordinary protected routes', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'c-1' });
    setMerchantGateState({ resolvedUserId: 'c-1', isMerchantRole: false, isAdmin: false });

    await renderRoute('/support');

    expect(await screen.findByText('/support — not yet implemented')).toBeTruthy();
  });
});
