/**
 * Ports `main_app_screen_test.dart`'s "entering a non-tab branch (e.g. a
 * service vertical) keeps the shell and its nav bar on screen instead of
 * stacking a full-screen route over it" case (issue #370) against this
 * app's `MainTabBar` (`_layout.tsx`). See
 * `main-tab-bar-state-preservation.test.tsx`'s top comment for why each
 * ported case here lives in its own file.
 *
 * `vertical` here stands in for `_layout.tsx`'s real, hidden food/grocery/
 * pharmacy branches (`href: null` `Tabs.Screen`s) -- same stand-in the
 * Flutter test's own `withVerticalBranch` branch plays for its real
 * service-vertical `StatefulShellBranch`es.
 */
import { router, Tabs } from 'expo-router';
import { fireEvent, renderRouter, screen } from 'expo-router/testing-library';
import { Pressable, Text } from 'react-native';

import { MainTabBar } from './_layout';

function OpenVerticalTab() {
  return (
    <Pressable accessibilityRole="button" onPress={() => router.push('/vertical')}>
      <Text>Open vertical</Text>
    </Pressable>
  );
}

function TestLayout() {
  return (
    <Tabs screenOptions={{ headerShown: false }} tabBar={(props: any) => <MainTabBar {...props} />}>
      <Tabs.Screen name="app" options={{ title: 'Home' }} />
      <Tabs.Screen name="explore" options={{ title: 'Explore' }} />
      <Tabs.Screen name="activity" options={{ title: 'Activity' }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile' }} />
      <Tabs.Screen name="vertical" options={{ title: 'Vertical', href: null }} />
    </Tabs>
  );
}

it(
  'entering a non-tab branch (e.g. a service vertical) keeps the shell ' +
    'and its nav bar on screen instead of stacking a full-screen route ' +
    'over it',
  async () => {
    const result = renderRouter(
      {
        _layout: TestLayout,
        app: OpenVerticalTab,
        explore: () => <Text>Explore test tab</Text>,
        activity: () => <Text>Activity test tab</Text>,
        profile: () => <Text>Profile test tab</Text>,
        vertical: () => <Text>Vertical test tab</Text>,
      },
      { initialUrl: '/app' },
    );
    await result;

    fireEvent.press(await screen.findByText('Open vertical'));

    // The vertical's own screen is showing...
    expect(await screen.findByText('Vertical test tab')).toBeTruthy();
    // ...but the persistent shell/nav bar is still there, still showing
    // the four primary tabs, with Home (the tab the vertical was opened
    // from) still highlighted rather than an out-of-range index or no
    // selection at all.
    expect(screen.getByText('Home')).toBeTruthy();
    expect(screen.getByText('Explore')).toBeTruthy();
    const homeButton = screen.getByLabelText('Home');
    expect(homeButton.props.accessibilityState?.selected).toBe(true);
  },
);
