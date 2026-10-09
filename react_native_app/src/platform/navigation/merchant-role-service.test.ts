/**
 * Ports `flutter_app/test/merchant_role_service_test.dart` (issue #363).
 *
 * `isAuthorizedMerchantRole` is unit-tested the same way the Flutter test
 * does it -- no Supabase dependency needed. `MerchantRoleService.fetchRole`
 * is exercised against `src/test-utils/fake-supabase-client.ts` instead of
 * a live Supabase project/network, mirroring that file's own stated intent.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { isAuthorizedMerchantRole, kAllowedMerchantRoles, MerchantRoleService } from './merchant-role-service';

// `merchant-role-service.ts` imports the real `@/platform/supabase/client`
// as its default `client` dependency, used only when a test doesn't inject
// its own (every test below does) -- see `session-store.test.ts`'s own
// top comment for why that module needs a stub rather than a bare `{}`
// under Jest (it loads env vars at import time, which aren't set here).
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

describe('isAuthorizedMerchantRole', () => {
  test('allows merchant', () => {
    expect(isAuthorizedMerchantRole('merchant')).toBe(true);
  });

  test('allows admin', () => {
    expect(isAuthorizedMerchantRole('admin')).toBe(true);
  });

  test('rejects customer', () => {
    expect(isAuthorizedMerchantRole('customer')).toBe(false);
  });

  test('rejects an unknown/unexpected role string', () => {
    expect(isAuthorizedMerchantRole('super_admin')).toBe(false);
  });

  test('rejects null (no profile row found, or the lookup failed)', () => {
    expect(isAuthorizedMerchantRole(null)).toBe(false);
  });

  test("kAllowedMerchantRoles matches the exact profiles_role_check set minus customer", () => {
    // Guards against silently drifting from the migration's check
    // constraint (`role in ('customer', 'merchant', 'admin')`) in
    // supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql
    // -- only merchant/admin route to the merchant dashboard.
    expect(new Set(kAllowedMerchantRoles)).toEqual(new Set(['merchant', 'admin']));
    expect(kAllowedMerchantRoles.has('customer')).toBe(false);
  });
});

describe('MerchantRoleService.fetchRole', () => {
  test('returns the role for an existing profile row', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse('profiles', fakeSupabaseOk({ role: 'merchant' }));

    const service = new MerchantRoleService({ client });
    await expect(service.fetchRole('m-1')).resolves.toBe('merchant');

    expect(client.calls).toEqual([
      {
        kind: 'table',
        name: 'profiles',
        steps: [
          { method: 'select', args: ['role'] },
          { method: 'eq', args: ['id', 'm-1'] },
          { method: 'maybeSingle', args: [] },
        ],
      },
    ]);
  });

  test('returns null when no profile row exists', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse('profiles', fakeSupabaseOk(null));

    const service = new MerchantRoleService({ client });
    await expect(service.fetchRole('c-1')).resolves.toBeNull();
  });

  test('returns null (fails closed) on a query error', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse('profiles', fakeSupabaseError('network error'));

    const service = new MerchantRoleService({ client });
    await expect(service.fetchRole('c-2')).resolves.toBeNull();
  });

  test('returns null (fails closed) when the client throws', async () => {
    const throwingClient = {
      from: () => {
        throw new Error('boom');
      },
    };

    const service = new MerchantRoleService({ client: throwingClient as never });
    await expect(service.fetchRole('c-3')).resolves.toBeNull();
  });

  test('isMerchantAccount combines fetchRole with isAuthorizedMerchantRole', async () => {
    const client = createFakeSupabaseClient();
    client.queueTableResponse('profiles', fakeSupabaseOk({ role: 'admin' }));

    const service = new MerchantRoleService({ client });
    await expect(service.isMerchantAccount('a-1')).resolves.toBe(true);
  });
});
