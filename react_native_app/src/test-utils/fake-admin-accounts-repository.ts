/**
 * Ports `flutter_app/test/helpers/fake_merchant_repositories.dart`'s
 * `FakeAdminAccountsRepository` (issue #412 / P9-07): an in-memory
 * `AdminAccountsRepository` for controller/screen tests.
 */
import type { AdminAccount } from '@/features/merchant/admin/api/admin-account';
import { AdminAccountsError } from '@/features/merchant/admin/api/admin-accounts-error';
import type { AdminAccountsRepository, ListAdminAccountsInput } from '@/features/merchant/admin/api/admin-accounts-repository';

export class FakeAdminAccountsRepository implements AdminAccountsRepository {
  private readonly accounts: AdminAccount[];

  /** When set, every method throws this instead of succeeding. */
  failureToThrow: unknown = null;

  /** The `search` argument of every `listAccounts` call, in order. */
  readonly searches: (string | null | undefined)[] = [];

  /** The `offset` argument of every `listAccounts` call, in order. */
  readonly offsets: number[] = [];

  constructor({ accounts = [] }: { accounts?: readonly AdminAccount[] } = {}) {
    this.accounts = [...accounts];
  }

  async listAccounts({ search, limit, offset }: ListAdminAccountsInput): Promise<AdminAccount[]> {
    this.searches.push(search);
    this.offsets.push(offset);
    if (this.failureToThrow != null) throw this.failureToThrow;
    const needle = (search ?? '').trim().toLowerCase();
    const matches = this.accounts.filter(
      (account) =>
        needle.length === 0 ||
        account.email.toLowerCase().includes(needle) ||
        `${account.firstName} ${account.lastName}`.trim().toLowerCase().includes(needle),
    );
    return matches.slice(offset, offset + limit);
  }

  async setRole({ profileId, newRole }: { profileId: string; newRole: string }): Promise<void> {
    if (this.failureToThrow != null) throw this.failureToThrow;
    const index = this.accounts.findIndex((account) => account.id === profileId);
    if (index < 0) throw new AdminAccountsError('Profile not found');
    this.accounts[index] = { ...this.accounts[index], role: newRole };
  }
}
