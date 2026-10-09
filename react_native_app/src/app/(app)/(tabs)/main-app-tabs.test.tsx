/**
 * Ports the three `flutter_app/test/main_app_screen_test.dart` cases that
 * have a real equivalent in this file's own scope
 * ((app)/(tabs)/_layout.tsx, issue #370):
 *  1. switching tabs preserves each branch's own in-tab state;
 *  2. an initial route resolves to the matching tab being visually selected;
 *  3. entering a hidden food/grocery/pharmacy branch keeps the nav bar on
 *     screen with the last primary tab still highlighted.
 *
 * The Dart suite's fourth case -- switching *to* the Activity tab reloads
 * it (`onActivityTabFocused`/`ActivityController.instance.load`), but
 * re-tapping the already-active tab doesn't -- has no RN equivalent yet:
 * no `ActivityController`-equivalent store or hook exists on this side (see
 * `src/stores/account-state-coordinator.ts`'s own "no RN cart/activity
 * controllers ... exist on the RN side yet" comment). There is nothing for
 * a `tabPress`-on-Activity handler here to call, and inventing one now
 * would mean building that mechanism inside this file, which is out of
 * scope for a router/tab-bar-chrome issue -- see this issue's final report
 * for where it belongs once a real Activity data store exists (most likely
 * a `useFocusEffect` inside `activity.tsx` itself, mirroring Dart's
 * `ActivityController.instance.load`, not this layout file).
 *
 * Renders the real route tree under `src/app` (so `(app)/_layout.tsx`'s
 * auth-redirect gate and this file's own `_layout.tsx` are both exercised
 * for real) via `expo-router/testing-library`'s `renderRouter`, using its
 * `{ appDir, overrides }` form (see `context-stubs.ts`'s
 * `requireContextWithOverrides`) to swap in small test-only components for
 * the `app` (Home) and `food/index` leaf screens -- this keeps the real
 * `app.tsx`/`food/index.tsx` placeholder files (owned by rn-ui-agent, out
 * of this issue's scope) untouched, while still exercising the real
 * `_layout.tsx` files around them. `explore.tsx`/`activity.tsx` are left
 * un-overridden; their real placeholder text already doubles as this
 * file's assertion anchor for "this is the right screen".
 *
 * See `route-reachability.test.tsx`'s top comment for why
 * `@/components/animated-icon` and `@/platform/supabase/client` are
 * mocked -- this file mounts the same real root `_layout.tsx` and hits the
 * same two concerns (`AnimatedSplashOverlay`'s native-worklets dependency,
 * and the Supabase client's env-var-reading side effect). As in that file,
 * the session store is left unmocked and at its default `status ===
 * 'loading'`, under which `(app)/_layout.tsx` renders unguarded (no
 * redirect) -- see that file's top comment for the full chain.
 *
 * Every `fireEvent.press` below is `await`ed, even though no call site
 * needs its resolved value: this RNTL version's `fireEvent.press` returns
 * `Promise<void>` (see `@testing-library/react-native/dist/events/fire-
 * event.d.ts`), and leaving that promise unawaited/dangling left its
 * continuation (an `act()` flush) resolve asynchronously *during the next
 * test's own render* instead -- observed as that next `renderRouter` call
 * mounting nothing at all (`screen.debug()` printing an empty `< />`) and
 * every one of its own queries failing, with no thrown error anywhere to
 * point at the cause. `welcome-back-navigation.test.tsx`'s top comment
 * documents a related but distinct `renderRouter`-reuses-fake-timers
 * pitfall in this same test harness; this is a second, independent one.
 */
import { fireEvent, renderRouter, screen, waitFor } from 'expo-router/testing-library';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';

jest.mock('@/components/animated-icon', () => ({ AnimatedSplashOverlay: () => null }));
jest.mock('@/platform/supabase/client', () => ({
  supabase: {
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));

/** Stands in for `app.tsx` (Home): an in-tab counter (case 1) plus a button into the hidden Food branch (case 3). */
function FakeHomeTab() {
  const [count, setCount] = useState(0);
  return (
    <View>
      <Text>{`Count ${count}`}</Text>
      <Pressable accessibilityRole="button" onPress={() => setCount((current) => current + 1)}>
        <Text>Increment</Text>
      </Pressable>
      <Pressable accessibilityRole="button" onPress={() => router.push('/food')}>
        <Text>Open vertical</Text>
      </Pressable>
    </View>
  );
}

/** Stands in for `food/index.tsx`: the hidden Food branch's own screen, for case 3. */
function FakeFoodIndex() {
  return (
    <View>
      <Text>Vertical test tab</Text>
    </View>
  );
}

async function renderMainApp(initialUrl: string) {
  const result = renderRouter(
    {
      appDir: 'src/app',
      overrides: {
        '(app)/(tabs)/app': FakeHomeTab,
        '(app)/(tabs)/food/index': FakeFoodIndex,
      },
    },
    { initialUrl },
  );
  await result;
  return result;
}

describe('bottom-nav tab bar ((app)/(tabs)/_layout.tsx, issue #370)', () => {
  test('switching tabs preserves each branch\'s own state (ports case 1)', async () => {
    await renderMainApp('/app');

    await fireEvent.press(screen.getByText('Increment'));
    await waitFor(() => expect(screen.getByText('Count 1')).toBeOnTheScreen());

    await fireEvent.press(screen.getByText('Explore'));
    await waitFor(() => expect(screen.getByText('/explore — not yet implemented')).toBeOnTheScreen());

    await fireEvent.press(screen.getByText('Home'));
    await waitFor(() => expect(screen.getByText('Count 1')).toBeOnTheScreen());
  });

  test('an initial route resolves to its matching tab being selected (ports case 2)', async () => {
    await renderMainApp('/activity');

    expect(await screen.findByText('/activity — not yet implemented')).toBeOnTheScreen();
    expect(screen.getByRole('tab', { name: 'Activity' })).toBeSelected();
    expect(screen.getByRole('tab', { name: 'Home' })).not.toBeSelected();
  });

  test('entering a hidden branch keeps the nav bar on screen with the last primary tab highlighted (ports case 3)', async () => {
    await renderMainApp('/app');

    await fireEvent.press(screen.getByText('Open vertical'));
    await waitFor(() => expect(screen.getByText('Vertical test tab')).toBeOnTheScreen());

    // The vertical's own screen is showing, but the four primary tabs (and
    // their nav bar) are still there, with Home -- the tab the vertical was
    // opened from -- still highlighted rather than unselected.
    expect(screen.getByText('Home')).toBeOnTheScreen();
    expect(screen.getByText('Explore')).toBeOnTheScreen();
    expect(screen.getByText('Activity')).toBeOnTheScreen();
    expect(screen.getByText('Profile')).toBeOnTheScreen();
    expect(screen.getByRole('tab', { name: 'Home' })).toBeSelected();
  });
});
