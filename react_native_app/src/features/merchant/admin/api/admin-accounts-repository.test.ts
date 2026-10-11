/**
 * RN coverage for `SupabaseAdminAccountsRepository` and the `AdminAccount`
 * model (issue #412 / P9-07). Ports the `AdminAccount` group of
 * `flutter_app/test/admin_accounts_controller_test.dart`; Flutter has no
 * repository-level test, so the RPC-shape cases are RN-only.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { adminAccountDisplayName, adminAccountFromRow, type AdminAccount } from './admin-account';
import { AdminAccountsError, SupabaseAdminAccountsRepository, type AdminAccountsSource } from './admin-accounts-repository';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function setup() {
  const fake = createFakeSupabaseClient();
  const repo = new SupabaseAdminAccountsRepository(fake as unknown as AdminAccountsSource);
  return { fake, repo };
}

describe('AdminAccount (admin_accounts_controller_test.dart)', () => {
  it('displayName falls back from name to email to id', () => {
    const named: AdminAccount = { id: 'i', firstName: 'Amal', lastName: 'Hassan', email: 'a@example.com', role: 'customer' };
    const unnamed: AdminAccount = { ...named, firstName: '', lastName: '' };
    const bare: AdminAccount = { ...unnamed, email: '' };

    expect(adminAccountDisplayName(named)).toBe('Amal Hassan');
    expect(adminAccountDisplayName(unnamed)).toBe('a@example.com');
    expect(adminAccountDisplayName(bare)).toBe('i');
  });

  it('fromMap tolerates null name and email', () => {
    const parsed = adminAccountFromRow({ id: 'i', firstname: null, lastname: null, email: null, role: 'admin' });

    expect(parsed.firstName).toBe('');
    expect(parsed.lastName).toBe('');
    expect(parsed.email).toBe('');
    expect(parsed.role).toBe('admin');
  });
});

describe('SupabaseAdminAccountsRepository', () => {
  it('listAccounts calls admin_list_profiles with search/limit/offset and maps rows', async () => {
    const { fake, repo } = setup();
    fake.queueRpcResponse(
      'admin_list_profiles',
      fakeSupabaseOk([{ id: 'p1', firstname: 'Amal', lastname: 'Hassan', email: 'amal@example.com', role: 'customer' }]),
    );

    const accounts = await repo.listAccounts({ search: 'amal', limit: 26, offset: 25 });

    expect(fake.calls).toEqual([
      expect.objectContaining({
        kind: 'rpc',
        name: 'admin_list_profiles',
        params: { search_text: 'amal', page_limit: 26, page_offset: 25 },
      }),
    ]);
    expect(accounts).toEqual([{ id: 'p1', firstName: 'Amal', lastName: 'Hassan', email: 'amal@example.com', role: 'customer' }]);
  });

  it('listAccounts treats a null payload as no rows', async () => {
    const { repo } = setup();

    await expect(repo.listAccounts({ limit: 26, offset: 0 })).resolves.toEqual([]);
  });

  it('listAccounts surfaces the RPC error message verbatim as AdminAccountsError', async () => {
    const { fake, repo } = setup();
    fake.queueRpcResponse('admin_list_profiles', fakeSupabaseError('Admin privileges required'));

    const promise = repo.listAccounts({ limit: 26, offset: 0 });
    await expect(promise).rejects.toBeInstanceOf(AdminAccountsError);
    await expect(promise).rejects.toThrow('Admin privileges required');
  });

  it('setRole calls admin_set_profile_role with the target and role', async () => {
    const { fake, repo } = setup();

    await repo.setRole({ profileId: 'p1', newRole: 'merchant' });

    expect(fake.calls).toEqual([
      expect.objectContaining({
        kind: 'rpc',
        name: 'admin_set_profile_role',
        params: { target_profile_id: 'p1', new_role: 'merchant' },
      }),
    ]);
  });

  it('setRole surfaces the RPC error message verbatim as AdminAccountsError', async () => {
    const { fake, repo } = setup();
    fake.queueRpcResponse('admin_set_profile_role', fakeSupabaseError('Cannot remove the last remaining admin'));

    const promise = repo.setRole({ profileId: 'p1', newRole: 'customer' });
    await expect(promise).rejects.toBeInstanceOf(AdminAccountsError);
    await expect(promise).rejects.toThrow('Cannot remove the last remaining admin');
  });
});
