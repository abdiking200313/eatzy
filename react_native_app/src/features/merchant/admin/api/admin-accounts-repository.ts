/**
 * Ports `flutter_app/lib/features/merchant/admin/data/admin_accounts_repository.dart`
 * (issue #412 / P9-07): data access for the admin-only "Accounts" screen --
 * listing/searching every account and changing one's `profiles.role`.
 *
 * Both operations are admin-gated server-side by the RPCs' own
 * `security definer` checks
 * (`20260921020000_add_admin_role_management_rpcs.sql`,
 * `20260922000000_add_admin_list_profiles_rpc.sql`), so this repository adds
 * no client-side authorization of its own: the client should never assume it
 * is allowed to call these just because the screen is reachable.
 */
import { supabase } from '@/platform/supabase/client';

import { adminAccountFromRow, type AdminAccount } from './admin-account';
import { AdminAccountsError } from './admin-accounts-error';

export { AdminAccountsError };

type SupabaseResult<T> = { data: T | null; error: { message?: string } | null };

/** The slice of `supabase` {@link SupabaseAdminAccountsRepository} depends on, so a test can inject the fake client. */
export interface AdminAccountsSource {
  rpc(name: string, params: Record<string, unknown>): PromiseLike<SupabaseResult<unknown>>;
}

export interface ListAdminAccountsInput {
  /** Matches anywhere in the email or full name, case-insensitively, when non-empty. */
  search?: string | null;
  limit: number;
  offset: number;
}

export interface AdminAccountsRepository {
  /** One page of accounts, newest sign-up first. Rejects with {@link AdminAccountsError} if the caller is not an admin. */
  listAccounts(input: ListAdminAccountsInput): Promise<AdminAccount[]>;

  /** Sets `profileId`'s `profiles.role` to `newRole`. Rejects with {@link AdminAccountsError} on any server rejection. */
  setRole(input: { profileId: string; newRole: string }): Promise<void>;
}

const FALLBACK_ERROR = 'The request was rejected.';

export class SupabaseAdminAccountsRepository implements AdminAccountsRepository {
  private readonly client: AdminAccountsSource;

  constructor(client: AdminAccountsSource = supabase as unknown as AdminAccountsSource) {
    this.client = client;
  }

  async listAccounts({ search, limit, offset }: ListAdminAccountsInput): Promise<AdminAccount[]> {
    const { data, error } = await this.client.rpc('admin_list_profiles', {
      search_text: search ?? null,
      page_limit: limit,
      page_offset: offset,
    });
    if (error) throw new AdminAccountsError(error.message ?? FALLBACK_ERROR);
    const rows = Array.isArray(data) ? (data as Record<string, unknown>[]) : [];
    return rows.map(adminAccountFromRow);
  }

  async setRole({ profileId, newRole }: { profileId: string; newRole: string }): Promise<void> {
    const { error } = await this.client.rpc('admin_set_profile_role', {
      target_profile_id: profileId,
      new_role: newRole,
    });
    if (error) throw new AdminAccountsError(error.message ?? FALLBACK_ERROR);
  }
}
