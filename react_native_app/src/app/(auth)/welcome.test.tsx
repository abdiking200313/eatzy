/**
 * Ports flutter_app/test/onboarding_screen_test.dart's behavioral
 * assertions (rendering, swiping, Skip/Get Started gating) to this screen's
 * RN implementation (issue #364).
 *
 * Unlike Flutter's `PageView` (which only builds the visible page plus a
 * couple of neighbors), this screen's plain horizontal `ScrollView` mounts
 * every slide's content up front — there is no RN "offstage" pass. So
 * instead of asserting a slide's content is *absent* before swiping to it
 * (as the Dart test does), these tests assert each slide's title is
 * present and track the active page via the pinned dots, which do reflect
 * the current scroll position.
 */
import { fireEvent } from '@testing-library/react-native';
import { Dimensions } from 'react-native';

import { renderWithProviders } from '@/test-utils';
import { useOnboardingStore } from '@/stores/onboarding-store';

import WelcomeScreen from './welcome';

jest.mock('expo-router', () => ({
  router: {
    replace: jest.fn(),
    push: jest.fn(),
  },
}));

const { router } = jest.requireMock('expo-router') as {
  router: { replace: jest.Mock; push: jest.Mock };
};

function resetOnboardingStore() {
  useOnboardingStore.setState({ status: 'idle', hasSeenOnboarding: false });
}

describe('WelcomeScreen (issue #364)', () => {
  beforeEach(() => {
    resetOnboardingStore();
    jest.clearAllMocks();
  });

  it('renders the first onboarding slide with Skip and Get Started', async () => {
    const { getByText, getAllByText } = await renderWithProviders(<WelcomeScreen />);

    expect(getByText("See What's Open Near You")).toBeOnTheScreen();
    expect(getAllByText('Ayam Penyet Ria').length).toBeGreaterThan(0);
    expect(getByText('Get Started')).toBeOnTheScreen();
    expect(getByText('Skip')).toBeOnTheScreen();
  });

  it('renders the second and third slides’ redesigned content', async () => {
    const { getByText } = await renderWithProviders(<WelcomeScreen />);

    expect(getByText('Order In A Few Taps')).toBeOnTheScreen();
    expect(getByText('Total incl. delivery')).toBeOnTheScreen();
    expect(getByText('Know Exactly When It Lands')).toBeOnTheScreen();
    expect(getByText('On the way')).toBeOnTheScreen();
    expect(getByText('Rider picked up')).toBeOnTheScreen();
  });

  it('marks the first page dot active and the rest inactive initially', async () => {
    const { getByTestId } = await renderWithProviders(<WelcomeScreen />);

    expect(getByTestId('onboarding-dot-0')).toHaveStyle({ width: 32 });
    expect(getByTestId('onboarding-dot-1')).toHaveStyle({ width: 8 });
    expect(getByTestId('onboarding-dot-2')).toHaveStyle({ width: 8 });
  });

  it('moves the active dot to the next page when the pager scrolls', async () => {
    const { getByTestId } = await renderWithProviders(<WelcomeScreen />);
    const { width, height } = Dimensions.get('window');

    await fireEvent.scroll(getByTestId('welcome-pager'), {
      nativeEvent: {
        contentOffset: { x: width, y: 0 },
        contentSize: { width: width * 3, height },
        layoutMeasurement: { width, height },
      },
    });

    expect(getByTestId('onboarding-dot-0')).toHaveStyle({ width: 8 });
    expect(getByTestId('onboarding-dot-1')).toHaveStyle({ width: 32 });
  });

  it('tapping Skip marks onboarding seen and replaces to the main app', async () => {
    const { getByText } = await renderWithProviders(<WelcomeScreen />);

    await fireEvent.press(getByText('Skip'));

    expect(useOnboardingStore.getState().hasSeenOnboarding).toBe(true);
    expect(router.replace).toHaveBeenCalledWith('/app');
    expect(router.push).not.toHaveBeenCalled();
  });

  it('tapping Get Started marks onboarding seen and pushes to register', async () => {
    const { getByText } = await renderWithProviders(<WelcomeScreen />);

    await fireEvent.press(getByText('Get Started'));

    expect(useOnboardingStore.getState().hasSeenOnboarding).toBe(true);
    expect(router.push).toHaveBeenCalledWith('/register');
    expect(router.replace).not.toHaveBeenCalled();
  });

  it('tapping Log In marks onboarding seen and pushes to login', async () => {
    const { getByText } = await renderWithProviders(<WelcomeScreen />);

    await fireEvent.press(getByText('Log In'));

    expect(useOnboardingStore.getState().hasSeenOnboarding).toBe(true);
    expect(router.push).toHaveBeenCalledWith('/login');
    expect(router.replace).not.toHaveBeenCalled();
  });
});
