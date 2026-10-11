/**
 * Ports `flutter_app/test/admin_accounts_screen_test.dart` (issue #412 /
 * P9-07) against the in-memory `FakeAdminAccountsRepository`.
 *
 * RN adaptations: the Dart `DropdownButton` is a pressable picker
 * (`testID="role-<id>"`) whose menu entries are `menuitem`s; the Dart
 * `AlertDialog` is `Alert.alert`, whose buttons are invoked from the spy; the
 * debounce is exercised with real timers and `waitFor`.
 */
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { Alert, type AlertButton } from 'react-native';

import { FakeAdminAccountsRepository } from '@/test-utils/fake-admin-accounts-repository';

import type { AdminAccount } from './api/admin-account';
import { AdminAccountsError } from './api/admin-accounts-repository';
import { ADMIN_ACCOUNTS_PAGE_SIZE, AdminAccountsController } from './admin-accounts-controller';
import { AdminAccountsScreen } from './admin-accounts-screen';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));

const me: AdminAccount = { id: 'admin-1', firstName: 'Owner', lastName: 'Admin', email: 'owner@example.com', role: 'admin' };
const amal: AdminAccount = { id: 'profile-1', firstName: 'Amal', lastName: 'Hassan', email: 'amal@example.com', role: 'customer' };
const bilal: AdminAccount = { id: 'profile-2', firstName: 'Bilal', lastName: 'Noor', email: 'bilal@example.com', role: 'merchant' };

async function renderScreen({
  accounts = [me, amal, bilal],
  repository,
}: { accounts?: AdminAccount[]; repository?: FakeAdminAccountsRepository } = {}) {
  const controller = new AdminAccountsController({ repository: repository ?? new FakeAdminAccountsRepository({ accounts }) });
  await render(<AdminAccountsScreen controller={controller} currentUserId={me.id} />);
  await waitFor(() => expect(controller.isLoading).toBe(false));
  return controller;
}

/**
 * Gives the list a tall viewport (the Dart test's `physicalSize = Size(800,
 * 4000)`), so `FlatList` virtualization renders every appended row instead
 * of only its initial batch.
 */
async function layoutTallList() {
  const list = screen.getByTestId('admin-accounts-list');
  await fireEvent(list, 'layout', { nativeEvent: { layout: { x: 0, y: 0, width: 800, height: 4000 } } });
  await fireEvent(list, 'contentSizeChange', 800, 4000);
  await fireEvent.scroll(list, {
    nativeEvent: {
      contentOffset: { x: 0, y: 0 },
      contentSize: { width: 800, height: 4000 },
      layoutMeasurement: { width: 800, height: 4000 },
    },
  });
}

/** Opens `id`'s role picker and picks `label`; returns the confirmation `Alert.alert` call's buttons, if any. */
async function pickRole(alertSpy: jest.SpyInstance, id: string, role: string) {
  await fireEvent.press(screen.getByTestId(`role-${id}`));
  await fireEvent.press(screen.getByTestId(`role-option-${id}-${role}`));
  return alertSpy.mock.calls.at(-1) as [string, string, AlertButton[]] | undefined;
}

let alertSpy: jest.SpyInstance;

beforeEach(() => {
  alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
});

afterEach(() => {
  alertSpy.mockRestore();
});

describe('AdminAccountsScreen (admin_accounts_screen_test.dart)', () => {
  it('lists every account with its name, email and role', async () => {
    await renderScreen();

    expect(screen.getByText('Amal Hassan')).toBeTruthy();
    expect(screen.getByText('amal@example.com')).toBeTruthy();
    expect(screen.getByText('Bilal Noor')).toBeTruthy();
    expect(screen.getByText('bilal@example.com')).toBeTruthy();
    expect(screen.getByText('Customer')).toBeTruthy();
    expect(screen.getByText('Merchant')).toBeTruthy();
    expect(screen.getByText('Admin')).toBeTruthy();
  });

  it("disables the signed-in admin's own picker", async () => {
    await renderScreen();

    expect(screen.getByText('You')).toBeTruthy();
    expect(screen.getByTestId('role-admin-1')).toBeDisabled();
    expect(screen.getByTestId('role-profile-1')).not.toBeDisabled();
  });

  it('shows an empty state when there are no accounts', async () => {
    await renderScreen({ accounts: [] });

    expect(screen.getByText('No accounts yet.')).toBeTruthy();
  });

  it('shows the server error with a retry that reloads', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: [amal] });
    repository.failureToThrow = new AdminAccountsError('Admin privileges required');
    await renderScreen({ repository });

    expect(screen.getByText('Admin privileges required')).toBeTruthy();

    repository.failureToThrow = null;
    await fireEvent.press(screen.getByRole('button', { name: 'Try again' }));

    expect(await screen.findByText('Amal Hassan')).toBeTruthy();
  });

  it('typing in the search box filters after a short debounce', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: [me, amal, bilal] });
    await renderScreen({ repository });

    await fireEvent.changeText(screen.getByPlaceholderText('Search by name or email'), 'bilal');
    // Not yet: the search waits for the admin to stop typing.
    expect(repository.searches).toEqual(['']);

    await waitFor(() => expect(repository.searches.at(-1)).toBe('bilal'));
    await waitFor(() => expect(screen.queryByText('Amal Hassan')).toBeNull());
    expect(screen.getByText('Bilal Noor')).toBeTruthy();
  });

  it('shows a no-match message for a search with no results', async () => {
    await renderScreen();

    await fireEvent.changeText(screen.getByPlaceholderText('Search by name or email'), 'zzz');

    expect(await screen.findByText('No accounts match "zzz".')).toBeTruthy();
  });

  it('"Load more" appends the next page', async () => {
    const many: AdminAccount[] = Array.from({ length: ADMIN_ACCOUNTS_PAGE_SIZE + 2 }, (_, i) => ({
      id: `p${i}`,
      firstName: 'Person',
      lastName: `${i}`,
      email: `person${i}@example.com`,
      role: 'customer',
    }));
    await renderScreen({ accounts: many });

    expect(screen.getByText('Person 24')).toBeTruthy();
    expect(screen.queryByText('Person 25')).toBeNull();

    await fireEvent.press(screen.getByRole('button', { name: 'Load more' }));

    await waitFor(() => expect(screen.queryByRole('button', { name: 'Load more' })).toBeNull());
    await layoutTallList();
    expect(await screen.findByText('Person 25')).toBeTruthy();
    expect(screen.getByText('Person 26')).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Load more' })).toBeNull();
  });

  it('confirming a role change saves it and shows a snackbar', async () => {
    const controller = await renderScreen();

    const call = await pickRole(alertSpy, 'profile-1', 'merchant');

    // Confirmation appears before anything is changed.
    expect(call?.[0]).toBe("Change Amal Hassan's role?");
    expect(call?.[1]).toBe('This changes Amal Hassan from customer to merchant.');
    expect(controller.accounts[1].role).toBe('customer');

    await act(async () => call![2].find((b) => b.text === 'Confirm')!.onPress!());

    expect(controller.accounts[1].role).toBe('merchant');
    expect(await screen.findByText('Amal Hassan is now merchant.')).toBeTruthy();
  });

  it('cancelling the confirmation leaves the role unchanged', async () => {
    const controller = await renderScreen();

    const call = await pickRole(alertSpy, 'profile-1', 'admin');
    expect(call?.[1]).toBe(
      "Amal Hassan will be able to manage every account's role, including granting or removing other admins.",
    );
    // Dismissing via the "Cancel" button runs no handler.
    expect(call![2].find((b) => b.text === 'Cancel')!.onPress).toBeUndefined();

    expect(controller.accounts[1].role).toBe('customer');
    expect(screen.getByTestId('role-profile-1')).toHaveAccessibleName('Role: Customer');
  });

  it('a rejected role change shows the server message', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: [me, amal, bilal] });
    const controller = await renderScreen({ repository });
    repository.failureToThrow = new AdminAccountsError('Admin privileges required');

    const call = await pickRole(alertSpy, 'profile-1', 'merchant');
    await act(async () => call![2].find((b) => b.text === 'Confirm')!.onPress!());

    expect(await screen.findByText('Admin privileges required')).toBeTruthy();
    expect(controller.accounts[1].role).toBe('customer');
  });
});

describe('AdminAccountsScreen (RN-only cases)', () => {
  it('picking the current role again asks for nothing', async () => {
    await renderScreen();

    await pickRole(alertSpy, 'profile-1', 'customer');

    expect(alertSpy).not.toHaveBeenCalled();
  });

  it('a failed "Load more" shows the error with a retry', async () => {
    const many: AdminAccount[] = Array.from({ length: ADMIN_ACCOUNTS_PAGE_SIZE + 1 }, (_, i) => ({
      id: `p${i}`,
      firstName: 'Person',
      lastName: `${i}`,
      email: '',
      role: 'customer',
    }));
    const repository = new FakeAdminAccountsRepository({ accounts: many });
    await renderScreen({ repository });

    repository.failureToThrow = new Error('network down');
    await fireEvent.press(screen.getByRole('button', { name: 'Load more' }));

    expect(await screen.findByText('More accounts could not be loaded. Please try again.')).toBeTruthy();
    repository.failureToThrow = null;
    await fireEvent.press(screen.getByRole('button', { name: 'Try again' }));
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Try again' })).toBeNull());
    await layoutTallList();
    expect(await screen.findByText('Person 25')).toBeTruthy();
  });
});
