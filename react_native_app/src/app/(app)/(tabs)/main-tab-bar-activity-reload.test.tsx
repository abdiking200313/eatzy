/**
 * Ports `main_app_screen_test.dart`'s "switching to the Activity tab
 * reloads it, but re-tapping it does not" case (issue #370) against this
 * app's `MainTabBar` (`_layout.tsx`). See
 * `main-tab-bar-state-preservation.test.tsx`'s top comment for why each
 * ported case here lives in its own file.
 *
 * `onActivityTabFocused` stands in for `MainTabBar`'s real default
 * (`noopActivityReload`, a stand-in for Flutter's `ActivityController.
 * instance.load` -- this app has no ported `ActivityController` yet), the
 * same way the Flutter test overrides `MainAppScreen.onActivityTabFocused`
 * to observe the reload without a real controller.
 */
import { Tabs } from 'expo-router';
import { fireEvent, renderRouter, screen, waitFor } from 'expo-router/testing-library';
import { Text } from 'react-native';

import { MainTabBar } from './_layout';

it('switching to the Activity tab reloads it, but re-tapping it does not', async () => {
  let focusCount = 0;

  function TestLayout() {
    return (
      <Tabs
        screenOptions={{ headerShown: false }}
        tabBar={(props: any) => (
          <MainTabBar
            {...props}
            onActivityTabFocused={() => {
              focusCount++;
            }}
          />
        )}>
        <Tabs.Screen name="app" options={{ title: 'Home' }} />
        <Tabs.Screen name="explore" options={{ title: 'Explore' }} />
        <Tabs.Screen name="activity" options={{ title: 'Activity' }} />
        <Tabs.Screen name="profile" options={{ title: 'Profile' }} />
      </Tabs>
    );
  }

  const result = renderRouter(
    {
      _layout: TestLayout,
      app: () => <Text>Home test tab</Text>,
      explore: () => <Text>Explore test tab</Text>,
      activity: () => <Text>Activity test tab</Text>,
      profile: () => <Text>Profile test tab</Text>,
    },
    { initialUrl: '/app' },
  );
  await result;
  expect(focusCount).toBe(0);

  fireEvent.press(await screen.findByText('Explore'));
  await waitFor(() => expect(screen.getByText('Explore test tab')).toBeTruthy());
  expect(focusCount).toBe(0);

  fireEvent.press(screen.getByText('Activity'));
  await waitFor(() => expect(screen.getByText('Activity test tab')).toBeTruthy());
  expect(focusCount).toBe(1);

  fireEvent.press(screen.getByText('Activity'));
  await waitFor(() => expect(screen.getByText('Activity test tab')).toBeTruthy());
  expect(focusCount).toBe(1);

  fireEvent.press(screen.getByText('Home'));
  await waitFor(() => expect(screen.getByText('Home test tab')).toBeTruthy());
  fireEvent.press(screen.getByText('Activity'));
  await waitFor(() => expect(focusCount).toBe(2));
});
