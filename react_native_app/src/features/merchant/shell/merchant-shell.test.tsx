/**
 * Ports `flutter_app/test/merchant_shell_test.dart` (issue #406 / P9-01),
 * plus the default-wiring, sign-out-failure and signed-out cases the Dart
 * file doesn't cover.
 *
 * The Dart test asserts on the real `MyStoreScreen`/`OrdersScreen` empty
 * states ("You don't have a store yet" / "Set up your store first") and the
 * real `AdminAccountsScreen` list. `MyStoreScreen` is real since P9-02
 * (#407): the Supabase client is mocked with the shared fake client, whose
 * unconfigured queries resolve to no rows, so it lands on the same "no
 * store yet" empty state. `OrdersScreen` is real since P9-03 (#408) and,
 * sharing the shell's store controller, lands on the Dart test's same "Set
 * up your store first" state. `AdminAccountsScreen` is still a placeholder
 * (the unscheduled Accounts port), so those cases assert on its own copy.
 *
 * `expo-router` is mocked the same way `profile.test.tsx` mocks it, and the
 * two stores the shell reads its defaults from are mocked the same way
 * `src/merchant-redirect.test.tsx` mocks them.
 */
import { fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { supabase } from '@/platform/supabase/client';
import type { FakeSupabaseClient } from '@/test-utils/fake-supabase-client';
import { useMerchantSessionGateStore, type MerchantSessionGateState } from '@/stores/merchant-session-gate';
import { useSessionStore, type SessionState } from '@/stores/session-store';

import { MerchantShell } from './merchant-shell';

jest.mock('expo-router', () => ({
  router: { push: jest.fn(), replace: jest.fn(), canGoBack: jest.fn(() => false), back: jest.fn() },
}));
jest.mock('@/platform/supabase/client', () => ({
  supabase: jest.requireActual('@/test-utils/fake-supabase-client').createFakeSupabaseClient(),
}));
jest.mock('@/stores/session-store', () => ({ useSessionStore: jest.fn() }));
jest.mock('@/stores/merchant-session-gate', () => ({ useMerchantSessionGateStore: jest.fn() }));

const mockedUseSessionStore = useSessionStore as unknown as jest.Mock;
const mockedUseMerchantSessionGateStore = useMerchantSessionGateStore as unknown as jest.Mock;

const MY_STORE_EMPTY_STATE = "You don't have a store yet";
const ORDERS_PLACEHOLDER = 'Set up your store first';
const ACCOUNTS_PLACEHOLDER = 'Account management is coming soon';

function setStores(session: Partial<SessionState>, gate: Partial<MerchantSessionGateState>) {
  const sessionState: SessionState = { status: 'signedIn', session: null, userId: null, ...session };
  const gateState: MerchantSessionGateState = { resolvedUserId: null, isMerchantRole: false, isAdmin: false, ...gate };
  mockedUseSessionStore.mockImplementation((selector: (state: SessionState) => unknown) => selector(sessionState));
  mockedUseMerchantSessionGateStore.mockImplementation((selector: (state: MerchantSessionGateState) => unknown) =>
    selector(gateState),
  );
}

function fakeAuth(signOut: () => Promise<void> = async () => {}) {
  return { signOut: jest.fn(signOut) };
}

beforeEach(() => {
  jest.clearAllMocks();
  setStores({}, {});
});

describe('MerchantShell (merchant_shell_test.dart)', () => {
  it('shows "My Store" destination by default', async () => {
    await render(<MerchantShell ownerId="merchant-1" auth={fakeAuth()} />);

    expect(screen.getByRole('tab', { name: 'My Store' })).toBeTruthy();
    expect(screen.getByRole('tab', { name: 'Orders' })).toBeTruthy();
    expect(screen.getByRole('tab', { name: 'My Store' }).props.accessibilityState).toEqual({ selected: true });
    expect(await screen.findByText(MY_STORE_EMPTY_STATE)).toBeVisible();
    expect(screen.queryByText(ORDERS_PLACEHOLDER)).toBeNull();
  });

  it('switching to Orders shows the Orders destination', async () => {
    await render(<MerchantShell ownerId="merchant-1" auth={fakeAuth()} />);
    await screen.findByText(MY_STORE_EMPTY_STATE);

    await fireEvent.press(screen.getByRole('tab', { name: 'Orders' }));

    expect(screen.getByText(ORDERS_PLACEHOLDER)).toBeVisible();
    expect(screen.queryByText(MY_STORE_EMPTY_STATE)).toBeNull();
    expect(screen.getByRole('tab', { name: 'Orders' }).props.accessibilityState).toEqual({ selected: true });

    // Switching back keeps both destinations mounted (the Dart `IndexedStack`).
    await fireEvent.press(screen.getByRole('tab', { name: 'My Store' }));
    expect(await screen.findByText(MY_STORE_EMPTY_STATE)).toBeVisible();
    expect(screen.getByText(ORDERS_PLACEHOLDER, { includeHiddenElements: true })).not.toBeVisible();
  });

  it('never shows the admin Accounts list to a plain merchant', async () => {
    await render(<MerchantShell ownerId="merchant-1" isAdmin={false} auth={fakeAuth()} />);

    expect(screen.getByRole('tab', { name: 'My Store' })).toBeTruthy();
    expect(screen.getByRole('tab', { name: 'Orders' })).toBeTruthy();
    expect(screen.queryByText(ACCOUNTS_PLACEHOLDER, { includeHiddenElements: true })).toBeNull();
    expect(screen.getByText('Zivo Merchant')).toBeTruthy();
    expect(screen.queryByText('Zivo Admin')).toBeNull();
  });

  it('an admin sees only the Accounts list and sign out', async () => {
    await render(<MerchantShell ownerId="admin-1" isAdmin auth={fakeAuth()} />);

    expect(screen.getByText('Zivo Admin')).toBeTruthy();
    expect(screen.getByText(ACCOUNTS_PLACEHOLDER)).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Sign out' })).toBeTruthy();

    // None of the merchant destinations exist for an admin.
    expect(screen.queryByRole('tablist', { includeHiddenElements: true })).toBeNull();
    expect(screen.queryByText('My Store', { includeHiddenElements: true })).toBeNull();
    expect(screen.queryByText('Orders', { includeHiddenElements: true })).toBeNull();
    expect(screen.queryByText(MY_STORE_EMPTY_STATE, { includeHiddenElements: true })).toBeNull();
    expect(screen.queryByText(ORDERS_PLACEHOLDER, { includeHiddenElements: true })).toBeNull();
  });

  it('signing out calls AuthService.signOut and returns to login', async () => {
    const auth = fakeAuth();
    await render(<MerchantShell ownerId="merchant-1" auth={auth} />);

    await fireEvent.press(screen.getByRole('button', { name: 'Sign out' }));

    await waitFor(() => expect(router.replace).toHaveBeenCalledWith('/login'));
    expect(auth.signOut).toHaveBeenCalledTimes(1);
  });
});

describe('MerchantShell (RN-only cases)', () => {
  it('shares one store controller between My Store and Orders, so the store is fetched once', async () => {
    const fake = supabase as unknown as FakeSupabaseClient;
    const callsBefore = fake.calls.filter((call) => call.name === 'restaurants').length;
    await render(<MerchantShell ownerId="merchant-1" auth={fakeAuth()} />);
    await screen.findByText(MY_STORE_EMPTY_STATE);

    await fireEvent.press(screen.getByRole('tab', { name: 'Orders' }));
    expect(screen.getByText(ORDERS_PLACEHOLDER)).toBeVisible();

    expect(fake.calls.filter((call) => call.name === 'restaurants').length - callsBefore).toBe(1);
  });

  it('defaults ownerId and isAdmin from the session store and merchant-session gate', async () => {
    setStores({ userId: 'admin-1' }, { resolvedUserId: 'admin-1', isMerchantRole: true, isAdmin: true });

    await render(<MerchantShell auth={fakeAuth()} />);

    expect(screen.getByText('Zivo Admin')).toBeTruthy();
    expect(screen.getByText(ACCOUNTS_PLACEHOLDER)).toBeTruthy();
  });

  it('defaults to the merchant destinations for a resolved non-admin merchant', async () => {
    setStores({ userId: 'merchant-1' }, { resolvedUserId: 'merchant-1', isMerchantRole: true, isAdmin: false });

    await render(<MerchantShell auth={fakeAuth()} />);

    expect(screen.getByText('Zivo Merchant')).toBeTruthy();
    expect(await screen.findByText(MY_STORE_EMPTY_STATE)).toBeVisible();
  });

  it('stays on the dashboard and shows an alert when sign-out fails', async () => {
    const alertSpy = jest.spyOn(Alert, 'alert').mockImplementation(() => {});
    const auth = fakeAuth(async () => {
      throw new Error('network down');
    });
    await render(<MerchantShell ownerId="merchant-1" auth={auth} />);

    await fireEvent.press(screen.getByRole('button', { name: 'Sign out' }));

    await waitFor(() => expect(alertSpy).toHaveBeenCalled());
    expect(alertSpy.mock.calls[0][0]).toMatch(/^Could not sign out: /);
    expect(router.replace).not.toHaveBeenCalled();
    alertSpy.mockRestore();
  });

  it('shows the session-ended prompt, not the dashboard, when there is no signed-in user', async () => {
    await render(<MerchantShell ownerId={null} auth={fakeAuth()} />);

    expect(screen.getByText('Your session has ended')).toBeTruthy();
    expect(screen.getByText('Sign in again to get back to your store.')).toBeTruthy();
    expect(screen.queryByText('Zivo Merchant')).toBeNull();
    expect(screen.queryByRole('tablist', { includeHiddenElements: true })).toBeNull();

    await fireEvent.press(screen.getByRole('button', { name: 'Sign in' }));
    expect(router.replace).toHaveBeenCalledWith('/login');
  });

  it('falls back to the session store, which may also have no user', async () => {
    setStores({ status: 'signedOut', userId: null }, {});

    await render(<MerchantShell auth={fakeAuth()} />);

    expect(screen.getByText('Your session has ended')).toBeTruthy();
  });
});
