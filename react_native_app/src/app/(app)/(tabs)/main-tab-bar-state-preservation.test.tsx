/**
 * Ports `main_app_screen_test.dart`'s "bottom navigation preserves each
 * branch's own state" case (issue #370) against this app's `MainTabBar`
 * (`_layout.tsx`).
 *
 * Like the Flutter test's `buildTestRouter` (a fresh `GoRouter` +
 * `MainAppScreen` per test, with test-only tab screens, rather than the
 * real app's routes), this mounts a small, self-contained `expo-router`
 * tree via `renderRouter`'s in-memory `MemoryContext` form: a `_layout`
 * that wires the real `MainTabBar` up to `Tabs`, plus test-only screens
 * named `app`/`explore`/`activity`/`profile` (matching `PRIMARY_TABS`'
 * route names in `_layout.tsx`).
 *
 * Kept in its own file rather than alongside the other three ported cases
 * below: `expo-router/testing-library`'s `renderRouter` mounts `ExpoRoot`
 * on top of a single module-level router-state store
 * (`expo-router/build/global-state/router-store`) that outlives any one
 * `renderRouter` call's own unmount within a test file. This case's own
 * multi-step interaction (increment the counter, switch tabs, switch back)
 * leaves that store in a state that made a *different* file's later,
 * differently-shaped `renderRouter` call resolve its initial URL
 * incorrectly when both lived in the same file -- the same class of
 * cross-test leakage `route-reachability.test.tsx`'s top comment documents
 * for a *skipped* `await`, except this one still reproduced even with every
 * render properly awaited. One `renderRouter` tree per file sidesteps it.
 */
import { Tabs } from 'expo-router';
import { fireEvent, renderRouter, screen } from 'expo-router/testing-library';
import { useState } from 'react';
import { Pressable, Text } from 'react-native';

import { MainTabBar } from './_layout';

function CounterTab() {
  const [count, setCount] = useState(0);
  return (
    <>
      <Text>{`Count ${count}`}</Text>
      <Pressable accessibilityRole="button" accessibilityLabel="increment-tab-counter" onPress={() => setCount((value) => value + 1)}>
        <Text>+</Text>
      </Pressable>
    </>
  );
}

function TestLayout() {
  return (
    <Tabs screenOptions={{ headerShown: false }} tabBar={(props: any) => <MainTabBar {...props} />}>
      <Tabs.Screen name="app" options={{ title: 'Home' }} />
      <Tabs.Screen name="explore" options={{ title: 'Explore' }} />
      <Tabs.Screen name="activity" options={{ title: 'Activity' }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile' }} />
    </Tabs>
  );
}

it("bottom navigation preserves each branch's own state", async () => {
  const result = renderRouter(
    {
      _layout: TestLayout,
      app: CounterTab,
      explore: () => <Text>Explore test tab</Text>,
      activity: () => <Text>Activity test tab</Text>,
      profile: () => <Text>Profile test tab</Text>,
    },
    { initialUrl: '/app' },
  );
  await result;

  fireEvent.press(await screen.findByText('+'));
  expect(await screen.findByText('Count 1')).toBeTruthy();

  fireEvent.press(screen.getByText('Explore'));
  expect(await screen.findByText('Explore test tab')).toBeTruthy();

  fireEvent.press(screen.getByText('Home'));
  // The counter is still 1 -- the Home branch was kept mounted (not torn
  // down and rebuilt) while Explore was active, same as Flutter's
  // `IndexedStack`-backed `StatefulShellRoute.indexedStack` branches.
  expect(await screen.findByText('Count 1')).toBeTruthy();
});
