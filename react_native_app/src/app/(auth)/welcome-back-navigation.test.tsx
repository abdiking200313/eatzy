/**
 * Ports the navigation-history intent of
 * flutter_app/test/auth_back_to_onboarding_test.dart: "Get Started" and
 * "Log In" push on top of the welcome/onboarding slides (so the back-stack
 * still leads back to them), while "Skip" replaces the screen entirely (a
 * terminal exit, with nothing to back into).
 *
 * The Dart test's own assertions key off real login/register screen *text*
 * ("Welcome back", "Create your account", a `Tooltip: 'Back'` button). When
 * this file was first written, `src/app/(auth)/login.tsx` and
 * `register.tsx` were still issue #358's placeholder stubs (real content
 * landed in #365/#366), so the describe block directly below ports what the
 * app state at the time actually supported instead: the route/back-stack
 * behavior itself, asserted via `getPathname()` and `router.canGoBack()`/
 * `router.back()` rather than screen text.
 *
 * #365/#366 have since landed a real "Back" button (`accessibilityLabel`
 * `'Back'`) and real heading text on both screens, including the exact
 * `handleBack` fallback (`router.canGoBack() ? router.back() :
 * router.replace(welcomeRevisit)`) `auth_back_to_onboarding_test.dart`'s
 * "nothing behind it" cases exist to cover. The second describe block below
 * (issue #369) restores the Dart test's own text-based assertions and
 * drives the *real* on-screen Back button (`screen.getByLabelText('Back')`)
 * instead of calling `router.back()` directly, covering the two
 * "nothing behind it" cases (login, register) the first describe block
 * couldn't exercise yet.
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

describe('welcome screen back-navigation via the real screen Back button (ports auth_back_to_onboarding_test.dart, issue #369)', () => {
  beforeEach(() => {
    useOnboardingStore.setState({ status: 'idle', hasSeenOnboarding: false });
  });

  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
  });

  it('back on login with nothing behind it opens the onboarding', async () => {
    const { result } = await renderRoute('/login');
    expect(await screen.findByText('Welcome back')).toBeOnTheScreen();
    expect(router.canGoBack()).toBe(false);

    await fireEvent.press(screen.getByLabelText('Back'));

    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));
    expect(await screen.findByText("See What's Open Near You")).toBeOnTheScreen();
    expect(screen.queryByText('Welcome back')).toBeNull();
  });

  it('back on register with nothing behind it opens the onboarding', async () => {
    const { result } = await renderRoute('/register');
    expect(await screen.findByText('Create your account')).toBeOnTheScreen();
    expect(router.canGoBack()).toBe(false);

    await fireEvent.press(screen.getByLabelText('Back'));

    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));
    expect(await screen.findByText("See What's Open Near You")).toBeOnTheScreen();
  });

  it('from the reopened onboarding, Log In still works and back returns to it', async () => {
    const { result } = await renderRoute('/login');

    await fireEvent.press(screen.getByLabelText('Back'));
    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));
    expect(await screen.findByText("See What's Open Near You")).toBeOnTheScreen();

    await fireEvent.press(await screen.findByText('Log In'));
    await waitFor(() => expect(result.getPathname()).toBe('/login'));
    expect(await screen.findByText('Welcome back')).toBeOnTheScreen();
    // Login now sits on top of the reopened onboarding, so back just pops
    // to it (same invariant the first describe block's "Get Started and Log
    // In..." case already covers via `router.back()` -- this asserts the
    // same thing through the real on-screen button instead).
    expect(router.canGoBack()).toBe(true);

    await fireEvent.press(screen.getByLabelText('Back'));
    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));
    expect(await screen.findByText("See What's Open Near You")).toBeOnTheScreen();
  });

  it('back still pops normally when register was pushed on top of another screen', async () => {
    const { result } = await renderRoute('/welcome?revisit=true');
    expect(await screen.findByText("See What's Open Near You")).toBeOnTheScreen();

    await act(async () => router.push('/register'));
    await waitFor(() => expect(result.getPathname()).toBe('/register'));
    expect(await screen.findByText('Create your account')).toBeOnTheScreen();

    await fireEvent.press(screen.getByLabelText('Back'));

    await waitFor(() => expect(result.getPathname()).toBe('/welcome'));
    expect(await screen.findByText("See What's Open Near You")).toBeOnTheScreen();
  });
});
