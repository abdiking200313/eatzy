/**
 * Ports `flutter_app/test/profile_screen_test.dart` (issue #399 / P8-03),
 * plus logout and option-navigation cases the Dart file doesn't cover.
 *
 * `expo-router` is mocked the same way `explore.test.tsx` mocks it, with
 * `useFocusEffect` captured so a test can simulate returning to the tab.
 * `@/platform/supabase/client` is stubbed as a bare `{}` -- the default
 * `SupabaseProfileRepository` then fails on `auth.getSession`, standing in
 * for the Dart test's "fake AppScope client with no real session".
 *
 * The Dart icon-absence assertions (`Icons.edit_outlined`/`Icons.verified`)
 * have no direct RNTL equivalent; the text-absence assertions alongside
 * them carry the same intent.
 */
import { act, fireEvent, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import type { CustomerProfile } from '@/features/profile/api/customer-profile';
import type { ProfileRepository } from '@/features/profile/api/profile-repository';
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { renderWithProviders } from '@/test-utils';

import ProfileScreen from './profile';

const mockFocusCallbacks: (() => void)[] = [];

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), replace: jest.fn(), canGoBack: jest.fn(() => false), back: jest.fn() },
  useFocusEffect: (callback: () => void) => {
    mockFocusCallbacks.push(callback);
  },
}));

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

class FakeErrorReporter implements ErrorReporter {
  readonly reported: { error: unknown; context?: string }[] = [];
  reportError(error: unknown, _stack?: string, context?: string): void {
    this.reported.push({ error, context });
  }
}

function repositoryReturning(profile: CustomerProfile | null): ProfileRepository & { fetchCurrentProfile: jest.Mock } {
  return {
    fetchCurrentProfile: jest.fn(async () => profile),
    updateProfile: async () => {
      throw new Error('not exercised by this test');
    },
    deleteAccount: async () => {
      throw new Error('not exercised by this test');
    },
  };
}

const amina: CustomerProfile = {
  id: 'customer-1',
  firstName: 'Amina',
  lastName: 'Noor',
  phone: '+252 61 234 5678',
  avatarUrl: null,
  dob: null,
};

const originalReporter = ErrorReporting.instance;
let reporter: FakeErrorReporter;

beforeEach(() => {
  reporter = new FakeErrorReporter();
  ErrorReporting.instance = reporter;
  mockFocusCallbacks.length = 0;
  jest.clearAllMocks();
});

afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

describe('ProfileScreen', () => {
  it('renders the empty state using the default Supabase-backed repository when none is injected', async () => {
    const { findByText } = await renderWithProviders(<ProfileScreen />);

    expect(await findByText('Zivo customer')).toBeOnTheScreen();
  });

  it('shows customer identity without activity statistics', async () => {
    const { findByText, getByText, queryByText } = await renderWithProviders(
      <ProfileScreen profileRepository={repositoryReturning(amina)} />,
    );

    expect(await findByText('Amina Noor')).toBeOnTheScreen();
    expect(getByText('+252 61 234 5678')).toBeOnTheScreen();
    // Addresses and Wallet are hidden while delivery addresses and payments
    // are out of scope.
    expect(queryByText('Addresses')).toBeNull();
    expect(queryByText('Wallet')).toBeNull();
    expect(getByText('Settings')).toBeOnTheScreen();
    expect(getByText('Logout')).toBeOnTheScreen();
    // Profile editing lives in Settings; no standalone edit entry point here.
    expect(queryByText('Edit Profile')).toBeNull();

    for (const removed of ['Gold Member', 'Activity', 'Active', 'Completed', 'Cancelled']) {
      expect(queryByText(removed)).toBeNull();
    }
  });

  it('removes the Coupons & Offers row and routes Notifications to Settings instead of a dead tap target', async () => {
    const { findByText, queryByText } = await renderWithProviders(
      <ProfileScreen profileRepository={repositoryReturning(null)} />,
    );

    expect(await findByText('Zivo customer')).toBeOnTheScreen();
    expect(queryByText('Coupons & Offers')).toBeNull();

    await fireEvent.press(await findByText('Notifications'));
    expect(router.push).toHaveBeenCalledWith('/settings');
  });

  it('a failed profile load still renders the empty state, but reports the error instead of swallowing it', async () => {
    const loadError = new Error('profile lookup failed');
    const repository = repositoryReturning(null);
    repository.fetchCurrentProfile.mockRejectedValue(loadError);

    const { findByText } = await renderWithProviders(<ProfileScreen profileRepository={repository} />);

    expect(await findByText('Zivo customer')).toBeOnTheScreen();
    expect(reporter.reported).toEqual([{ error: loadError, context: 'ProfileScreen.loadProfile' }]);
  });

  it('shows the fallback contact line when the profile has no phone', async () => {
    const { findByText } = await renderWithProviders(
      <ProfileScreen profileRepository={repositoryReturning({ ...amina, phone: '' })} />,
    );

    expect(await findByText('Somalia • USD')).toBeOnTheScreen();
  });

  it('pushes Help & Support to /support', async () => {
    const { findByText } = await renderWithProviders(<ProfileScreen profileRepository={repositoryReturning(amina)} />);

    await fireEvent.press(await findByText('Help & Support'));

    expect(router.push).toHaveBeenCalledWith('/support');
  });

  it('reloads the profile on returning from Settings, but not from other options', async () => {
    const repository = repositoryReturning(amina);
    const { findByText } = await renderWithProviders(<ProfileScreen profileRepository={repository} />);
    await findByText('Amina Noor');
    expect(repository.fetchCurrentProfile).toHaveBeenCalledTimes(1);
    const refocus = () =>
      act(async () => {
        mockFocusCallbacks[mockFocusCallbacks.length - 1]();
      });

    await fireEvent.press(await findByText('Help & Support'));
    await refocus();
    expect(repository.fetchCurrentProfile).toHaveBeenCalledTimes(1);

    repository.fetchCurrentProfile.mockResolvedValue({ ...amina, firstName: 'Hodan' });
    await fireEvent.press(await findByText('Settings'));
    await refocus();

    expect(await findByText('Hodan Noor')).toBeOnTheScreen();
    expect(repository.fetchCurrentProfile).toHaveBeenCalledTimes(2);
  });

  it('signs out and navigates to login on Logout', async () => {
    const auth = { signOut: jest.fn(async () => {}) };
    const { findByText } = await renderWithProviders(
      <ProfileScreen profileRepository={repositoryReturning(amina)} auth={auth} />,
    );

    await fireEvent.press(await findByText('Logout'));

    await waitFor(() => expect(router.replace).toHaveBeenCalledWith('/login'));
    expect(auth.signOut).toHaveBeenCalledTimes(1);
  });

  it('shows an error and stays put when sign-out fails', async () => {
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    const auth = { signOut: jest.fn(async () => Promise.reject(new Error('offline'))) };
    const { findByText } = await renderWithProviders(
      <ProfileScreen profileRepository={repositoryReturning(amina)} auth={auth} />,
    );

    await fireEvent.press(await findByText('Logout'));

    await waitFor(() =>
      expect(alertSpy).toHaveBeenCalledWith(
        'Could not log out: Something went wrong. Please check your connection and try again.',
      ),
    );
    expect(router.replace).not.toHaveBeenCalled();
    alertSpy.mockRestore();
  });
});
