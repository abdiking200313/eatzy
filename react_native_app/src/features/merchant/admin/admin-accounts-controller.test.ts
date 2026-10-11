/**
 * Ports `flutter_app/test/admin_accounts_controller_test.dart` (issue #412 /
 * P9-07) against the in-memory `FakeAdminAccountsRepository` (the
 * `AdminAccount` model group lives in `api/admin-accounts-repository.test.ts`),
 * plus RN-only cases for the stale-response guard and error reporting.
 */
import { ErrorReporting, type ErrorReporter } from '@/platform/error-reporting/error-reporter';
import { FakeAdminAccountsRepository } from '@/test-utils/fake-admin-accounts-repository';

import type { AdminAccount } from './api/admin-account';
import { AdminAccountsError, type AdminAccountsRepository } from './api/admin-accounts-repository';
import { ADMIN_ACCOUNTS_PAGE_SIZE, AdminAccountsController } from './admin-accounts-controller';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function account(i: number, role = 'customer'): AdminAccount {
  return { id: `profile-${i}`, firstName: 'User', lastName: `${i}`, email: `user${i}@example.com`, role };
}

function accounts(count: number): AdminAccount[] {
  return Array.from({ length: count }, (_, index) => account(index + 1));
}

let originalReporter: ErrorReporter;
let reportError: jest.Mock;

beforeEach(() => {
  originalReporter = ErrorReporting.instance;
  reportError = jest.fn();
  ErrorReporting.instance = { reportError };
});

afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

describe('load', () => {
  it('loads the first page and reports no more when it all fits', async () => {
    const controller = new AdminAccountsController({ repository: new FakeAdminAccountsRepository({ accounts: accounts(3) }) });

    await controller.load();

    expect(controller.isLoading).toBe(false);
    expect(controller.loadError).toBeNull();
    expect(controller.accounts.map((a) => a.id)).toEqual(['profile-1', 'profile-2', 'profile-3']);
    expect(controller.hasMore).toBe(false);
  });

  it('caps the first page at pageSize and reports more', async () => {
    const controller = new AdminAccountsController({
      repository: new FakeAdminAccountsRepository({ accounts: accounts(ADMIN_ACCOUNTS_PAGE_SIZE + 1) }),
    });

    await controller.load();

    expect(controller.accounts).toHaveLength(ADMIN_ACCOUNTS_PAGE_SIZE);
    expect(controller.hasMore).toBe(true);
  });

  it('an exactly-full last page reports no more', async () => {
    const controller = new AdminAccountsController({
      repository: new FakeAdminAccountsRepository({ accounts: accounts(ADMIN_ACCOUNTS_PAGE_SIZE) }),
    });

    await controller.load();

    expect(controller.accounts).toHaveLength(ADMIN_ACCOUNTS_PAGE_SIZE);
    expect(controller.hasMore).toBe(false);
  });

  it('filters by the trimmed search text', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: accounts(12) });
    const controller = new AdminAccountsController({ repository });

    await controller.load('  USER11 ');

    expect(controller.query).toBe('USER11');
    expect(repository.searches.at(-1)).toBe('USER11');
    expect(controller.accounts.map((a) => a.id)).toEqual(['profile-11']);
  });

  it('sets loadError and clears accounts on failure', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: accounts(2) });
    const controller = new AdminAccountsController({ repository });
    await controller.load();

    repository.failureToThrow = new AdminAccountsError('Admin privileges required');
    await controller.load();

    expect(controller.isLoading).toBe(false);
    expect(controller.loadError).toBe('Admin privileges required');
    expect(controller.accounts).toHaveLength(0);
  });

  it('uses a generic message for unexpected errors', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: accounts(1) });
    repository.failureToThrow = new Error('network down');
    const controller = new AdminAccountsController({ repository });

    await controller.load();

    expect(controller.loadError).not.toBeNull();
    expect(controller.loadError).not.toContain('network down');
    expect(reportError).toHaveBeenCalledWith(expect.any(Error), expect.anything(), 'AdminAccountsController.load');
  });

  it('(RN) discards a stale, slower response once a newer search has started', async () => {
    const fake = new FakeAdminAccountsRepository({ accounts: accounts(12) });
    let releaseFirst: () => void = () => {};
    let calls = 0;
    const repository: AdminAccountsRepository = {
      async listAccounts(input) {
        calls += 1;
        if (calls === 1) await new Promise<void>((resolve) => (releaseFirst = resolve));
        return fake.listAccounts(input);
      },
      setRole: (input) => fake.setRole(input),
    };
    const controller = new AdminAccountsController({ repository });

    const first = controller.load('user1');
    await controller.load('user12');
    releaseFirst();
    await first;

    expect(controller.query).toBe('user12');
    expect(controller.accounts.map((a) => a.id)).toEqual(['profile-12']);
    expect(controller.isLoading).toBe(false);
  });
});

describe('loadMore', () => {
  it('appends the next page using the loaded count as offset', async () => {
    const total = ADMIN_ACCOUNTS_PAGE_SIZE + 5;
    const repository = new FakeAdminAccountsRepository({ accounts: accounts(total) });
    const controller = new AdminAccountsController({ repository });
    await controller.load();

    await controller.loadMore();

    expect(repository.offsets).toEqual([0, ADMIN_ACCOUNTS_PAGE_SIZE]);
    expect(controller.accounts).toHaveLength(total);
    expect(controller.accounts.at(-1)?.id).toBe(`profile-${total}`);
    expect(controller.hasMore).toBe(false);
  });

  it('is a no-op when there is nothing more to load', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: accounts(2) });
    const controller = new AdminAccountsController({ repository });
    await controller.load();

    await controller.loadMore();

    expect(repository.offsets).toEqual([0]);
  });

  it('a failure keeps the loaded accounts and sets loadMoreError', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: accounts(ADMIN_ACCOUNTS_PAGE_SIZE + 1) });
    const controller = new AdminAccountsController({ repository });
    await controller.load();

    repository.failureToThrow = new Error('network down');
    await controller.loadMore();

    expect(controller.accounts).toHaveLength(ADMIN_ACCOUNTS_PAGE_SIZE);
    expect(controller.loadMoreError).not.toBeNull();
    expect(controller.loadError).toBeNull();
    expect(controller.isLoadingMore).toBe(false);
    expect(controller.hasMore).toBe(true);
  });
});

describe('setRole', () => {
  it('returns false for an account that is not loaded', async () => {
    const controller = new AdminAccountsController({ repository: new FakeAdminAccountsRepository({ accounts: accounts(1) }) });
    await controller.load();

    expect(await controller.setRole('nobody', 'merchant')).toBe(false);
  });

  it('updates the loaded account on success', async () => {
    const controller = new AdminAccountsController({ repository: new FakeAdminAccountsRepository({ accounts: accounts(2) }) });
    await controller.load();

    const succeeded = await controller.setRole('profile-2', 'merchant');

    expect(succeeded).toBe(true);
    expect(controller.saveError).toBeNull();
    expect(controller.savingId).toBeNull();
    expect(controller.accounts[0].role).toBe('customer');
    expect(controller.accounts[1].role).toBe('merchant');
  });

  it('marks the account as saving while the request is in flight', async () => {
    const controller = new AdminAccountsController({ repository: new FakeAdminAccountsRepository({ accounts: accounts(1) }) });
    await controller.load();

    const seen: (string | null)[] = [];
    controller.subscribe(() => seen.push(controller.savingId));
    await controller.setRole('profile-1', 'admin');

    expect(seen[0]).toBe('profile-1');
    expect(controller.savingId).toBeNull();
  });

  it('a rejection sets saveError and leaves the role unchanged', async () => {
    const repository = new FakeAdminAccountsRepository({ accounts: accounts(1) });
    const controller = new AdminAccountsController({ repository });
    await controller.load();
    repository.failureToThrow = new AdminAccountsError('Cannot remove the last remaining admin');

    const succeeded = await controller.setRole('profile-1', 'admin');

    expect(succeeded).toBe(false);
    expect(controller.saveError).toBe('Cannot remove the last remaining admin');
    expect(controller.savingId).toBeNull();
    expect(controller.accounts[0].role).toBe('customer');
  });
});
