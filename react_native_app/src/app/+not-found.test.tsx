/**
 * Ports flutter_app/test/app_router_test.dart's "NotFoundScreen shows a
 * message and a way back to a known route (issue #40)" case (issue #543).
 * Like the Flutter test, this stands up a minimal route tree (a stub home
 * screen at `/app` plus the real `+not-found` screen) rather than the full
 * root layout, so auth/session redirects stay out of the picture.
 *
 * `renderRouter` switches to fake timers on every call, so `afterEach`
 * flushes and restores them (same teardown as
 * `(auth)/welcome-back-navigation.test.tsx`).
 */
import { fireEvent, renderRouter, screen, waitFor } from 'expo-router/testing-library';
import { Text } from 'react-native';

import NotFoundScreen from './+not-found';

function HomeStub() {
  return <Text>home screen</Text>;
}

describe('NotFoundScreen (+not-found)', () => {
  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
  });

  it('shows a message and a way back to a known route', async () => {
    const result = renderRouter(
      { 'app/index': HomeStub, '+not-found': NotFoundScreen },
      { initialUrl: '/this-path-does-not-exist' },
    );
    await result;

    expect(await screen.findByText("We couldn't find that page")).toBeOnTheScreen();
    expect(screen.getByText('Page not found')).toBeOnTheScreen();
    expect(
      screen.getByText('The link may be out of date, or the page may have moved.'),
    ).toBeOnTheScreen();
    expect(screen.queryByText('home screen')).toBeNull();

    await fireEvent.press(screen.getByText('Go to home'));

    await waitFor(() => expect(result.getPathname()).toBe('/app'));
    expect(await screen.findByText('home screen')).toBeOnTheScreen();
    expect(screen.queryByText("We couldn't find that page")).toBeNull();

    screen.unmount();
  });
});
