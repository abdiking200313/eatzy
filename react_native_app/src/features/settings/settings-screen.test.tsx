/**
 * Ports the account-editing, Coming soon, and Support cases of
 * `flutter_app/test/settings_screen_test.dart` (issue #400 / P8-04), plus
 * its four notification-preference cases (#401 / P8-05), plus its three
 * delete-account cases (#402 / P8-06). The Dart file has no Logout case;
 * the Logout and "sign-out fails after deletion" cases here are RN-only
 * coverage of `_logout`/`_confirmDeleteAccount` branches. Flutter's
 * `AlertDialog` is the platform `Alert.alert` here, so the dialog is
 * driven through a spy (as in `cart-view.test.tsx`), and GoRouter's
 * "Login destination" route becomes `router.replace('/login')`.
 *
 * The two Privacy Policy / Terms
 * cases assert the real legal text, which lands with #404 (P8-08); here
 * they are narrowed to "the row navigates to that route".
 *
 * The Dart tests build a real signed-in `AuthService` on a mocked HTTP
 * client; this screen depends on the narrow `ProfileEmailAuth` seam, so a
 * recording fake stands in. `Icons.arrow_forward_ios` lookups become the
 * `setting-card-chevron` test ID.
 */
import { act, fireEvent, screen, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert, type AlertButton } from 'react-native';

import type { CustomerProfile } from '@/features/profile/api/customer-profile';
import type { ProfileRepository, ProfileUpdate } from '@/features/profile/api/profile-repository';
import type { ProfileEmailAuth } from '@/features/profile/profile-edit-controller';
import { ErrorReporting, NoopErrorReporter } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  type NotificationPreferencesStorage,
} from '@/features/settings/api/notification-preferences-repository';
import type { PushNotificationGateway } from '@/platform/notifications/push-notifications';
import {
  FakePushNotificationGateway,
  MemoryNotificationPreferencesStorage,
  renderWithProviders,
} from '@/test-utils';

import { DELETE_ACCOUNT_MESSAGE, DELETE_ACCOUNT_TITLE, SettingsScreen, type SettingsSignOut } from './settings-screen';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), replace: jest.fn(), canGoBack: jest.fn(() => false), back: jest.fn() },
}));

// `{}`: the default `SupabaseProfileRepository` then fails on
// `auth.getSession`, standing in for the Dart test's "fake AppScope client
// with no real session".
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

jest.mock('@/stores/session-store', () => ({
  useSessionStore: { getState: () => ({ session: null }) },
}));

// Same stand-in as register.test.tsx: the real native picker has no JS
// test renderer, so "OK" picks the 1995-06-15 date this mock is seeded
// with via `mockPickedDate`.
let mockPickedDate = new Date(1995, 5, 15);
jest.mock('@react-native-community/datetimepicker', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { Pressable, Text } = require('react-native');
  return {
    __esModule: true,
    default: ({ onChange }: { onChange: (event: { type: 'set' }, date: Date) => void }) => (
      <Pressable accessibilityRole="button" onPress={() => onChange({ type: 'set' }, mockPickedDate)}>
        <Text>Pick date</Text>
      </Pressable>
    ),
  };
});

class FakeProfileRepository implements ProfileRepository {
  readonly updateCalls: ProfileUpdate[] = [];
  deleteAccountCalled = false;

  constructor(
    private profile: CustomerProfile | null,
    private readonly updateError?: unknown,
    private readonly deleteAccountError?: unknown,
  ) {}

  async fetchCurrentProfile(): Promise<CustomerProfile | null> {
    return this.profile;
  }

  async updateProfile(update: ProfileUpdate): Promise<CustomerProfile> {
    this.updateCalls.push(update);
    if (this.updateError !== undefined) throw this.updateError;
    const current = this.profile ?? { id: 'customer-1', firstName: '', lastName: '', phone: '', avatarUrl: null, dob: null };
    const updated: CustomerProfile = {
      ...current,
      firstName: update.firstName ?? current.firstName,
      lastName: update.lastName ?? current.lastName,
      phone: update.phone ?? current.phone,
      dob: update.dob ?? current.dob,
    };
    this.profile = updated;
    return updated;
  }

  async deleteAccount(): Promise<void> {
    this.deleteAccountCalled = true;
    if (this.deleteAccountError !== undefined) throw this.deleteAccountError;
  }
}

class FakeEmailAuth implements ProfileEmailAuth {
  readonly updateEmailCalls: string[] = [];

  constructor(private readonly email: string | null) {}

  getCurrentUserEmail(): string | null {
    return this.email;
  }

  async updateEmail(email: string): Promise<void> {
    this.updateEmailCalls.push(email);
  }
}

/** Stands in for the Dart tests' real signed-in `AuthService`: `signedIn` is `getCurrentUserId() != null`. */
class FakeSignOut implements SettingsSignOut {
  signedIn = true;
  signOutCallCount = 0;

  constructor(private readonly signOutError?: unknown) {}

  async signOut(): Promise<void> {
    this.signOutCallCount += 1;
    if (this.signOutError !== undefined) throw this.signOutError;
    this.signedIn = false;
  }
}

function profileOf(overrides: Partial<CustomerProfile>): CustomerProfile {
  return { id: 'customer-1', firstName: 'Amina', lastName: 'Noor', phone: '+252 61 000 0000', avatarUrl: null, dob: null, ...overrides };
}

async function renderSettings(repository: ProfileRepository, email: string | null = 'user@zivo.app') {
  const emailAuth = new FakeEmailAuth(email);
  const result = await renderWithProviders(<SettingsScreen profileRepository={repository} emailAuth={emailAuth} />);
  await waitFor(() => expect(screen.queryByText('Loading…')).toBeNull());
  return { ...result, emailAuth };
}

const originalReporter = ErrorReporting.instance;

beforeEach(() => {
  ErrorReporting.instance = new NoopErrorReporter();
  mockPickedDate = new Date(1995, 5, 15);
  jest.clearAllMocks();
});

afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

describe('SettingsScreen', () => {
  test('renders using the default Supabase-backed repository when none is injected', async () => {
    await renderWithProviders(<SettingsScreen emailAuth={new FakeEmailAuth(null)} />);

    await waitFor(() => expect(screen.getAllByText('Not added yet').length).toBeGreaterThan(0));
    expect(screen.getByText('Not available')).toBeOnTheScreen();
  });

  test("shows the signed-in user's real name, phone, date of birth, and email, not placeholders", async () => {
    await renderSettings(
      new FakeProfileRepository(profileOf({ phone: '+252 61 111 2222', dob: new Date(1995, 5, 15) })),
      'amina@zivo.app',
    );

    expect(screen.getByText('Amina Noor')).toBeOnTheScreen();
    expect(screen.getByText('+252 61 111 2222')).toBeOnTheScreen();
    expect(screen.getByText('Jun 15, 1995')).toBeOnTheScreen();
    expect(screen.getByText('amina@zivo.app')).toBeOnTheScreen();
    expect(screen.queryByText('user@example.com')).toBeNull();
    expect(screen.queryByText('+1 234 567 8900')).toBeNull();
  });

  test('shows honest fallback text for a phone number and date of birth that are not on file', async () => {
    await renderSettings(new FakeProfileRepository(profileOf({ firstName: 'Sam', lastName: '', phone: '' })));

    expect(screen.getByText('Sam')).toBeOnTheScreen();
    expect(screen.getAllByText('Not added yet')).toHaveLength(2);
  });

  test('dead nav rows (Language/Currency/Theme) are honest placeholders with no chevron and no tap action', async () => {
    await renderSettings(new FakeProfileRepository(profileOf({ firstName: 'Sam', lastName: 'Yusuf' })));

    expect(screen.getAllByText('Coming soon')).toHaveLength(3);
    for (const title of ['Language', 'Currency', 'Theme']) {
      expect(screen.queryByRole('button', { name: title })).toBeNull();
    }
    // Name, Phone Number, Date of Birth, Email Address, Change Password,
    // About Us, Privacy Policy, Terms & Conditions.
    expect(screen.getAllByTestId('setting-card-chevron')).toHaveLength(8);
  });

  test('Privacy Policy navigates to the privacy policy route', async () => {
    await renderSettings(new FakeProfileRepository(profileOf({})));

    await fireEvent.press(screen.getByRole('button', { name: 'Privacy Policy' }));

    expect(router.push).toHaveBeenCalledWith(AppRoutes.privacyPolicy);
  });

  test('Terms & Conditions navigates to the terms route', async () => {
    await renderSettings(new FakeProfileRepository(profileOf({})));

    await fireEvent.press(screen.getByRole('button', { name: 'Terms & Conditions' }));

    expect(router.push).toHaveBeenCalledWith(AppRoutes.termsOfService);
  });

  test('Change Password navigates to the reset-password route', async () => {
    await renderSettings(new FakeProfileRepository(profileOf({})));

    await fireEvent.press(screen.getByRole('button', { name: 'Change Password' }));

    expect(router.push).toHaveBeenCalledWith(AppRoutes.resetPassword);
  });

  test('About Us opens a static info sheet instead of doing nothing', async () => {
    await renderSettings(new FakeProfileRepository(profileOf({})));
    expect(screen.queryByText('Version 1.0.0')).toBeNull();

    await fireEvent.press(screen.getByRole('button', { name: 'About Us' }));

    expect(await screen.findByText('Version 1.0.0')).toBeOnTheScreen();
    expect(screen.getByText(/Zivo is a modular delivery app/)).toBeOnTheScreen();
  });

  test('an empty first name in the Name sheet shows an inline error and does not call the repository', async () => {
    const repository = new FakeProfileRepository(profileOf({}));
    await renderSettings(repository);

    await fireEvent.press(screen.getByRole('button', { name: 'Name' }));
    await fireEvent.changeText(screen.getByDisplayValue('Amina'), '');
    await fireEvent.press(screen.getByText('Save'));

    expect(await screen.findByText('Enter your first name.')).toBeOnTheScreen();
    expect(repository.updateCalls).toHaveLength(0);
  });

  test('tapping Name opens the edit sheet prefilled with the current name, and saving updates the row and shows a confirmation', async () => {
    const repository = new FakeProfileRepository(profileOf({}));
    await renderSettings(repository);

    await fireEvent.press(screen.getByRole('button', { name: 'Name' }));
    expect(screen.getByDisplayValue('Amina')).toBeOnTheScreen();
    expect(screen.getByDisplayValue('Noor')).toBeOnTheScreen();

    await fireEvent.changeText(screen.getByDisplayValue('Noor'), 'Hassan');
    await fireEvent.press(screen.getByText('Save'));

    expect(await screen.findByText('Amina Hassan')).toBeOnTheScreen();
    // Phone/DOB weren't part of this edit, so they must stay unsent.
    expect(repository.updateCalls).toEqual([{ firstName: 'Amina', lastName: 'Hassan' }]);
    expect(screen.getByText('Profile updated')).toBeOnTheScreen();
    expect(screen.queryByText('Edit name')).toBeNull();
  });

  test('a repository failure while saving the Name sheet surfaces the generic save-failure message instead of silently doing nothing', async () => {
    const repository = new FakeProfileRepository(profileOf({}), new Error('network down'));
    await renderSettings(repository);

    await fireEvent.press(screen.getByRole('button', { name: 'Name' }));
    await fireEvent.press(screen.getByText('Save'));

    expect(await screen.findByText('Could not save your profile. Please try again.')).toBeOnTheScreen();
    expect(repository.updateCalls).toHaveLength(1);
    // The sheet stays open and the row behind it is unchanged.
    expect(screen.getByText('Edit name')).toBeOnTheScreen();
    expect(screen.getByText('Amina Noor')).toBeOnTheScreen();
  });

  test('saving a new email address in the Email sheet shows the confirm-inbox message instead of updating the profile row directly', async () => {
    const repository = new FakeProfileRepository(profileOf({}));
    const { emailAuth } = await renderSettings(repository, 'current@zivo.app');

    await fireEvent.press(screen.getByRole('button', { name: 'Email Address' }));
    // Matches both the settings row behind the sheet and the prefilled field.
    expect(screen.getByDisplayValue('current@zivo.app')).toBeOnTheScreen();

    await fireEvent.changeText(screen.getByDisplayValue('current@zivo.app'), 'new@zivo.app');
    await fireEvent.press(screen.getByText('Save'));

    expect(await screen.findByText('Check your new inbox to confirm your email change.')).toBeOnTheScreen();
    expect(emailAuth.updateEmailCalls).toEqual(['new@zivo.app']);
    // The address only takes effect once the link is confirmed, so the
    // profile repository is never touched and the row still shows the old email.
    expect(repository.updateCalls).toHaveLength(0);
    expect(screen.getByText('current@zivo.app')).toBeOnTheScreen();
  });

  test('an invalid phone number in the Phone sheet shows an inline error; a valid one saves and updates the row', async () => {
    const repository = new FakeProfileRepository(profileOf({}));
    await renderSettings(repository);

    await fireEvent.press(screen.getByRole('button', { name: 'Phone Number' }));
    await fireEvent.changeText(screen.getByDisplayValue('+252 61 000 0000'), '123');
    await fireEvent.press(screen.getByText('Save'));
    expect(await screen.findByText('Please enter a valid phone number.')).toBeOnTheScreen();
    expect(repository.updateCalls).toHaveLength(0);

    await fireEvent.changeText(screen.getByDisplayValue('123'), ' +252 61 999 8888 ');
    await fireEvent.press(screen.getByText('Save'));

    expect(await screen.findByText('+252 61 999 8888')).toBeOnTheScreen();
    expect(repository.updateCalls).toEqual([{ phone: '+252 61 999 8888' }]);
  });

  test('picking a date of birth saves only the date and updates the row', async () => {
    const repository = new FakeProfileRepository(profileOf({}));
    await renderSettings(repository);

    await fireEvent.press(screen.getByRole('button', { name: 'Date of Birth' }));
    await fireEvent.press(screen.getByText('Pick date'));

    expect(await screen.findByText('Jun 15, 1995')).toBeOnTheScreen();
    expect(repository.updateCalls).toEqual([{ dob: new Date(1995, 5, 15) }]);
    expect(screen.getByText('Profile updated')).toBeOnTheScreen();
  });
});

describe('SettingsScreen notifications', () => {
  function notificationSettings(
    ownerId: string,
    storage: NotificationPreferencesStorage,
    gateway: PushNotificationGateway = new FakePushNotificationGateway(true),
    key = 'first',
  ) {
    return (
      <SettingsScreen
        key={key}
        profileRepository={new FakeProfileRepository(profileOf({ id: ownerId }))}
        emailAuth={new FakeEmailAuth('user@zivo.app')}
        notificationPreferencesStorage={storage}
        pushNotificationGateway={gateway}
        getCurrentUserId={() => ownerId}
      />
    );
  }

  function renderNotificationSettings(
    ownerId: string,
    storage: NotificationPreferencesStorage,
    gateway?: PushNotificationGateway,
  ) {
    return renderWithProviders(notificationSettings(ownerId, storage, gateway));
  }

  const switchValue = (label: string): unknown => screen.getByLabelText(label).props.value;

  test('a toggled notification preference persists and is restored the next time the screen loads', async () => {
    const storage = new MemoryNotificationPreferencesStorage();
    const { rerender } = await renderNotificationSettings('customer-5', storage);
    await waitFor(() => expect(screen.queryByText('Loading…')).toBeNull());

    // "Email Notifications" starts off (the documented default).
    expect(switchValue('Email Notifications')).toBe(false);

    await fireEvent(screen.getByLabelText('Email Notifications'), 'valueChange', true);

    await waitFor(() => expect(switchValue('Email Notifications')).toBe(true));
    expect((await storage.read('customer-5')).emailNotifications).toBe(true);

    // Re-opening the screen (a brand-new instance, via a new `key`) restores
    // the persisted value instead of resetting to the default.
    await rerender(notificationSettings('customer-5', storage, undefined, 'reopened'));
    await waitFor(() => expect(switchValue('Email Notifications')).toBe(true));
  });

  test('turning push notifications on requests permission and persists it once granted', async () => {
    const storage = new MemoryNotificationPreferencesStorage();
    await storage.write('customer-11', { ...DEFAULT_NOTIFICATION_PREFERENCES, pushNotifications: false });
    const gateway = new FakePushNotificationGateway(true);
    await renderNotificationSettings('customer-11', storage, gateway);
    await waitFor(() => expect(screen.queryByText('Loading…')).toBeNull());
    expect(switchValue('Push Notifications')).toBe(false);

    await fireEvent(screen.getByLabelText('Push Notifications'), 'valueChange', true);

    await waitFor(() => expect(switchValue('Push Notifications')).toBe(true));
    expect(gateway.requestPermissionCallCount).toBe(1);
    expect((await storage.read('customer-11')).pushNotifications).toBe(true);
  });

  test('turning push notifications on stays off and warns when permission is denied', async () => {
    const storage = new MemoryNotificationPreferencesStorage();
    await storage.write('customer-12', { ...DEFAULT_NOTIFICATION_PREFERENCES, pushNotifications: false });
    const gateway = new FakePushNotificationGateway(false);
    await renderNotificationSettings('customer-12', storage, gateway);
    await waitFor(() => expect(screen.queryByText('Loading…')).toBeNull());

    await fireEvent(screen.getByLabelText('Push Notifications'), 'valueChange', true);

    expect(await screen.findByText(/Enable them in your device settings/)).toBeOnTheScreen();
    expect(switchValue('Push Notifications')).toBe(false);
    expect((await storage.read('customer-12')).pushNotifications).toBe(false);
  });

  test('a stored push-on preference is reconciled to off if OS permission was since revoked', async () => {
    const storage = new MemoryNotificationPreferencesStorage();
    await storage.write('customer-13', { ...DEFAULT_NOTIFICATION_PREFERENCES, pushNotifications: true });
    const gateway = new FakePushNotificationGateway(false);
    await renderNotificationSettings('customer-13', storage, gateway);

    await waitFor(async () => expect((await storage.read('customer-13')).pushNotifications).toBe(false));
    expect(switchValue('Push Notifications')).toBe(false);
  });

  test('turning push notifications off needs no permission and persists', async () => {
    const storage = new MemoryNotificationPreferencesStorage();
    const gateway = new FakePushNotificationGateway(true);
    await renderNotificationSettings('customer-14', storage, gateway);
    await waitFor(() => expect(screen.queryByText('Loading…')).toBeNull());
    expect(switchValue('Push Notifications')).toBe(true);

    await fireEvent(screen.getByLabelText('Push Notifications'), 'valueChange', false);

    await waitFor(() => expect(switchValue('Push Notifications')).toBe(false));
    expect(gateway.requestPermissionCallCount).toBe(0);
    expect((await storage.read('customer-14')).pushNotifications).toBe(false);
  });
});

describe('SettingsScreen account danger zone', () => {
  let alertSpy: jest.SpyInstance<void, Parameters<typeof Alert.alert>>;

  beforeEach(() => {
    alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
  });

  afterEach(() => {
    alertSpy.mockRestore();
  });

  async function renderDangerZone(repository: FakeProfileRepository, auth: FakeSignOut) {
    await renderWithProviders(
      <SettingsScreen profileRepository={repository} emailAuth={new FakeEmailAuth('user@zivo.app')} auth={auth} />,
    );
    await waitFor(() => expect(screen.queryByText('Loading…')).toBeNull());
  }

  /** Taps "Delete Account" and returns the confirmation dialog's buttons. */
  async function openDeleteDialog(): Promise<AlertButton[]> {
    await fireEvent.press(screen.getByRole('button', { name: 'Delete Account' }));
    expect(alertSpy).toHaveBeenCalledTimes(1);
    const [title, message, buttons] = alertSpy.mock.calls[0];
    expect(title).toBe(DELETE_ACCOUNT_TITLE);
    expect(message).toBe(DELETE_ACCOUNT_MESSAGE);
    return buttons ?? [];
  }

  async function press(buttons: AlertButton[], text: string) {
    const button = buttons.find((candidate) => candidate.text === text);
    expect(button).toBeDefined();
    await act(async () => {
      button?.onPress?.();
    });
  }

  test('renders Logout and Delete Account at the bottom of the screen', async () => {
    await renderDangerZone(new FakeProfileRepository(profileOf({})), new FakeSignOut());

    expect(screen.getByRole('button', { name: 'Logout' })).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Delete Account' })).toBeOnTheScreen();
  });

  test('canceling the delete-account confirmation dialog does not delete the account', async () => {
    const repository = new FakeProfileRepository(profileOf({ id: 'customer-6', firstName: 'Sam', lastName: 'Yusuf' }));
    const auth = new FakeSignOut();
    await renderDangerZone(repository, auth);

    const buttons = await openDeleteDialog();
    expect(buttons.map((button) => [button.text, button.style])).toEqual([
      ['Cancel', 'cancel'],
      ['Delete Account', 'destructive'],
    ]);
    await press(buttons, 'Cancel');

    expect(repository.deleteAccountCalled).toBe(false);
    expect(auth.signOutCallCount).toBe(0);
    expect(router.replace).not.toHaveBeenCalled();
    expect(screen.getByText('Notifications')).toBeOnTheScreen();
  });

  test('confirming account deletion calls the repository, signs out, and routes to login', async () => {
    const repository = new FakeProfileRepository(profileOf({ id: 'customer-7', firstName: 'Sam', lastName: 'Yusuf' }));
    const auth = new FakeSignOut();
    await renderDangerZone(repository, auth);

    await press(await openDeleteDialog(), 'Delete Account');

    expect(repository.deleteAccountCalled).toBe(true);
    expect(auth.signedIn).toBe(false);
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.login);
  });

  test('a failed account deletion shows an error and leaves the user signed in', async () => {
    const repository = new FakeProfileRepository(
      profileOf({ id: 'customer-8', firstName: 'Sam', lastName: 'Yusuf' }),
      undefined,
      new Error('boom'),
    );
    const auth = new FakeSignOut();
    await renderDangerZone(repository, auth);

    await press(await openDeleteDialog(), 'Delete Account');

    expect(repository.deleteAccountCalled).toBe(true);
    expect(await screen.findByText(/Could not delete account/)).toBeOnTheScreen();
    expect(auth.signOutCallCount).toBe(0);
    expect(auth.signedIn).toBe(true);
    expect(router.replace).not.toHaveBeenCalled();
  });

  test('a sign-out failure after a successful deletion is not reported as a failed deletion', async () => {
    const repository = new FakeProfileRepository(profileOf({}));
    const auth = new FakeSignOut(new Error('network down'));
    await renderDangerZone(repository, auth);

    await press(await openDeleteDialog(), 'Delete Account');

    expect(repository.deleteAccountCalled).toBe(true);
    expect(auth.signOutCallCount).toBe(1);
    expect(router.replace).toHaveBeenCalledWith(AppRoutes.login);
    expect(screen.queryByText(/Could not delete account/)).toBeNull();
  });

  test('Logout signs out and routes to login without a confirmation step', async () => {
    const repository = new FakeProfileRepository(profileOf({}));
    const auth = new FakeSignOut();
    await renderDangerZone(repository, auth);

    await fireEvent.press(screen.getByRole('button', { name: 'Logout' }));

    expect(alertSpy).not.toHaveBeenCalled();
    expect(repository.deleteAccountCalled).toBe(false);
    expect(auth.signedIn).toBe(false);
    await waitFor(() => expect(router.replace).toHaveBeenCalledWith(AppRoutes.login));
  });

  test('a failed Logout shows an error and stays on Settings', async () => {
    const auth = new FakeSignOut(new Error('network down'));
    await renderDangerZone(new FakeProfileRepository(profileOf({})), auth);

    await fireEvent.press(screen.getByRole('button', { name: 'Logout' }));

    expect(await screen.findByText(/Could not log out/)).toBeOnTheScreen();
    expect(router.replace).not.toHaveBeenCalled();
  });
});
