/**
 * Ports `flutter_app/test/profile_repository_test.dart` (issue #399 /
 * P8-03) against `src/test-utils/fake-supabase-client.ts` plus a plain
 * `auth.getSession` stub (same approach as `activity-repository.test.ts`),
 * instead of the Dart test's real `SupabaseClient` + `MockClient`. The
 * Dart "no params body is literally `null`" assertion becomes "the RPC is
 * called with no params at all"; a failed RPC's `PostgrestException`
 * becomes the returned `error` being thrown. Adds `fetchCurrentProfile`
 * coverage the Dart file doesn't have.
 */
import { createFakeSupabaseClient, fakeSupabaseError, fakeSupabaseOk } from '@/test-utils/fake-supabase-client';

import { ProfileSignInRequiredError, SupabaseProfileRepository, type ProfileSource } from './profile-repository';

// `profile-repository.ts` imports the real `@/platform/supabase/client` for
// its default `client`, which loads env vars at import time -- see
// `merchant-role-service.test.ts`.
jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));

function clientFor(userId: string | null) {
  const fake = createFakeSupabaseClient();
  const client = Object.assign(fake, {
    auth: {
      getSession: async () => ({ data: { session: userId ? { user: { id: userId } } : null } }),
    },
  });
  return { fake, client: client as unknown as ProfileSource };
}

function rowJson(dob: string | null = null) {
  return {
    id: 'customer-1',
    firstname: 'Amina',
    lastname: 'Noor',
    phone: '+252 61 234 5678',
    avatar_url: null,
    dob,
  };
}

describe('SupabaseProfileRepository.deleteAccount', () => {
  it("calls the delete_own_account RPC with no parameters -- the function is security definer and scopes itself to the caller's own auth.uid() server-side", async () => {
    const { fake, client } = clientFor('customer-1');

    await new SupabaseProfileRepository(client).deleteAccount();

    expect(fake.calls).toEqual([{ kind: 'rpc', name: 'delete_own_account', params: undefined, steps: [] }]);
  });

  it('surfaces the error from a failed RPC call', async () => {
    const { fake, client } = clientFor('customer-2');
    fake.queueRpcResponse('delete_own_account', fakeSupabaseError('Authentication required', { code: '42501' }));

    await expect(new SupabaseProfileRepository(client).deleteAccount()).rejects.toMatchObject({
      message: 'Authentication required',
      code: '42501',
    });
  });

  it('throws instead of calling the RPC when no user is signed in', async () => {
    const { fake, client } = clientFor(null);

    await expect(new SupabaseProfileRepository(client).deleteAccount()).rejects.toBeInstanceOf(
      ProfileSignInRequiredError,
    );
    expect(fake.calls).toHaveLength(0);
  });
});

describe('SupabaseProfileRepository.updateProfile', () => {
  it('calls the update_own_profile RPC with only the provided field, omitting the others entirely', async () => {
    const { fake, client } = clientFor('customer-1');
    fake.queueRpcResponse('update_own_profile', fakeSupabaseOk(rowJson()));

    await new SupabaseProfileRepository(client).updateProfile({ firstName: 'Amina' });

    expect(fake.calls).toEqual([
      {
        kind: 'rpc',
        name: 'update_own_profile',
        params: { p_firstname: 'Amina' },
        steps: [{ method: 'single', args: [] }],
      },
    ]);
  });

  it('formats dob as yyyy-MM-dd and sends it alongside other provided fields, still omitting phone', async () => {
    const { fake, client } = clientFor('customer-1');
    fake.queueRpcResponse('update_own_profile', fakeSupabaseOk(rowJson('1995-06-15')));

    await new SupabaseProfileRepository(client).updateProfile({
      firstName: 'Amina',
      lastName: 'Noor',
      dob: new Date(1995, 5, 15),
    });

    const call = fake.calls[0];
    expect(call.kind === 'rpc' && call.params).toEqual({
      p_firstname: 'Amina',
      p_lastname: 'Noor',
      p_dob: '1995-06-15',
    });
  });

  it('parses the returned row, including dob, into a CustomerProfile', async () => {
    const { fake, client } = clientFor('customer-1');
    fake.queueRpcResponse('update_own_profile', fakeSupabaseOk(rowJson('1995-06-15')));

    const profile = await new SupabaseProfileRepository(client).updateProfile({ dob: new Date(1995, 5, 15) });

    expect(profile.id).toBe('customer-1');
    expect(profile.firstName).toBe('Amina');
    expect(profile.lastName).toBe('Noor');
    expect(profile.phone).toBe('+252 61 234 5678');
    expect(profile.dob).toEqual(new Date(1995, 5, 15));
  });

  it('throws instead of calling the RPC when no user is signed in', async () => {
    const { fake, client } = clientFor(null);

    await expect(
      new SupabaseProfileRepository(client).updateProfile({ firstName: 'Amina' }),
    ).rejects.toBeInstanceOf(ProfileSignInRequiredError);
    expect(fake.calls).toHaveLength(0);
  });
});

describe('SupabaseProfileRepository.fetchCurrentProfile', () => {
  it("selects the signed-in user's own profiles row and parses it", async () => {
    const { fake, client } = clientFor('customer-1');
    fake.queueTableResponse('profiles', fakeSupabaseOk(rowJson()));

    const profile = await new SupabaseProfileRepository(client).fetchCurrentProfile();

    expect(profile?.firstName).toBe('Amina');
    expect(fake.calls[0]).toEqual({
      kind: 'table',
      name: 'profiles',
      steps: [
        { method: 'select', args: ['id, firstname, lastname, phone, avatar_url, dob'] },
        { method: 'eq', args: ['id', 'customer-1'] },
        { method: 'maybeSingle', args: [] },
      ],
    });
  });

  it('returns null when no profile row exists, and throws when signed out', async () => {
    const signedIn = clientFor('customer-1');
    await expect(new SupabaseProfileRepository(signedIn.client).fetchCurrentProfile()).resolves.toBeNull();

    const signedOut = clientFor(null);
    await expect(new SupabaseProfileRepository(signedOut.client).fetchCurrentProfile()).rejects.toBeInstanceOf(
      ProfileSignInRequiredError,
    );
    expect(signedOut.fake.calls).toHaveLength(0);
  });
});
