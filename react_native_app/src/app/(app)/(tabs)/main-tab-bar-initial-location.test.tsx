/**
 * Ports `main_app_screen_test.dart`'s "an initial location resolves to its
 * matching branch/tab" case (issue #370) against this app's `MainTabBar`
 * (`_layout.tsx`). See `main-tab-bar-state-preservation.test.tsx`'s top
 * comment for why each ported case here lives in its own file.
 */
import { Tabs } from 'expo-router';
import { renderRouter, screen } from 'expo-router/testing-library';
import { Text } from 'react-native';

import { MainTabBar } from './_layout';

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

it('an initial location resolves to its matching branch/tab', async () => {
  const result = renderRouter(
    {
      _layout: TestLayout,
      app: () => <Text>Home test tab</Text>,
      explore: () => <Text>Explore test tab</Text>,
      activity: () => <Text>Activity test tab</Text>,
      profile: () => <Text>Profile test tab</Text>,
    },
    { initialUrl: '/activity' },
  );
  await result;

  expect(await screen.findByText('Activity test tab')).toBeTruthy();
  const activityButton = screen.getByLabelText('Activity');
  expect(activityButton.props.accessibilityState?.selected).toBe(true);
});
