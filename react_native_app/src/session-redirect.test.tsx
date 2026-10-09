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
 * `@/components/animated-icon` and `@/platform/supabase/client` are
 * mocked -- this file mounts the same real root `_layout.tsx` and hits the
 * same two issues.
 */
import { renderRouter, screen, waitFor } from 'expo-router/testing-library';

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

const mockedUseSessionStore = useSessionStore as unknown as jest.Mock;

function setSessionState(state: SessionState) {
  mockedUseSessionStore.mockImplementation((selector: (state: SessionState) => unknown) =>
    selector(state),
  );
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

    expect(await screen.findByText('/welcome — not yet implemented')).toBeTruthy();
  });

  it('sends a signed-in user away from a signed-out-only route to /app', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'user-1' });

    const { result } = await renderRoute('/login');

    await waitFor(() => expect(result.getPathname()).toBe('/app'));
  });

  it('lets a signed-in user reach a protected (app) route', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'user-1' });

    await renderRoute('/support');

    expect(await screen.findByText('/support — not yet implemented')).toBeTruthy();
  });

  it('lets a signed-in user reach /reset-password (not a signed-out-only route)', async () => {
    setSessionState({ status: 'signedIn', session: null, userId: 'user-1' });

    await renderRoute('/reset-password');

    expect(await screen.findByText('/reset-password — not yet implemented')).toBeTruthy();
  });

  it('does not redirect yet while the session status is still loading', async () => {
    setSessionState({ status: 'loading', session: null, userId: null });

    await renderRoute('/app');

    expect(await screen.findByText('/app — not yet implemented')).toBeTruthy();
  });
});
