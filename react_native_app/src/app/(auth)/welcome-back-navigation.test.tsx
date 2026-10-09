/**
 * Ports the navigation-history intent of
 * flutter_app/test/auth_back_to_onboarding_test.dart: "Get Started" and
 * "Log In" push on top of the welcome/onboarding slides (so the back-stack
 * still leads back to them), while "Skip" replaces the screen entirely (a
 * terminal exit, with nothing to back into).
 *
 * The Dart test's own assertions key off real login/register screen *text*
 * ("Welcome back", "Create your account", a `Tooltip: 'Back'` button) that
 * doesn't exist yet — `src/app/(auth)/login.tsx` and `register.tsx` are
 * still issue #358's placeholder stubs (real content lands in #365/#366).
 * This ports what the current app state actually supports instead: the
 * route/back-stack behavior itself, asserted via `getPathname()` and
 * `router.canGoBack()`/`router.back()` rather than screen text. Once
 * #365/#366 land a real back button on those screens, a follow-up can
 * restore the exact text-based assertions the Dart test uses.
 *
 * See `src/route-reachability.test.tsx`'s top comment for why
 * `@/components/animated-icon`, `@/platform/supabase/client`, and
 * `@/platform/query/query-persistence` are mocked here too — this file
 * mounts the same real root `_layout.tsx`.
 *
 * Each scenario below renders its own tree in a single `it`, explicitly
 * `unmount()`s before the test ends, and flushes/restores real timers in
 * `afterEach` — `renderRouter` re-enables fake timers on every call (see its
 * own source), and without an explicit teardown a scheduler "Immediate" left
 * pending by one test's own `act(() => router.back())` call fires mid-render
 * in the *next* test instead, surfacing as spurious "overlapping act()
 * calls" warnings and a screen query that can't find text that is, in fact,
 * there.
 */
import { act, fireEvent, renderRouter, screen, waitFor } from 'expo-router/testing-library';
import { router } from 'expo-router';

import { useOnboardingStore } from '@/stores/onboarding-store';

jest.mock('@/components/animated-icon', () => ({ AnimatedSplashOverlay: () => null }));
jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));
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

async function renderRoute(path: string) {
  const result = renderRouter('src/app', { initialUrl: path });
  await result;
  return { result };
}

describe('welcome screen back-navigation (ports auth_back_to_onboarding_test.dart, issue #364)', () => {
  beforeEach(() => {
    useOnboardingStore.setState({ status: 'idle', hasSeenOnboarding: false });
  });

  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
  });

  it('Get Started and Log In both push on top of welcome, leaving it reachable via back', async () => {
    const { result } = await renderRoute('/welcome');

    await fireEvent.press(await screen.findByText('Get Started'));
    await waitFor(() => expect(result.getPathname()).toBe('/register'));
    expect(router.canGoBack()).toBe(true);

    await act(async () => router.back());
    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));

    await fireEvent.press(await screen.findByText('Log In'));
    await waitFor(() => expect(result.getPathname()).toBe('/login'));
    expect(router.canGoBack()).toBe(true);

    await act(async () => router.back());
    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));
  });

  it('Skip replaces to the main app with no back-stack entry for welcome', async () => {
    const { result } = await renderRoute('/welcome');

    await fireEvent.press(await screen.findByText('Skip'));

    await waitFor(() => expect(result.getPathname()).toBe('/app'));
    expect(router.canGoBack()).toBe(false);
  });

  it('reopening onboarding via ?revisit=true still lets Log In push and back return to it', async () => {
    const { result } = await renderRoute('/welcome?revisit=true');

    expect(result.getPathname()).toBe('/welcome');

    await fireEvent.press(await screen.findByText('Log In'));
    await waitFor(() => expect(result.getPathname()).toBe('/login'));

    await act(async () => router.back());
    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));
  });
});
