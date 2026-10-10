/**
 * Ports `flutter_app/lib/features/profile/data/profile_repository.dart`
 * (issue #399 / P8-03): `ProfileRepository` plus its Supabase-backed
 * implementation. `fetchCurrentProfile` backs the Profile tab;
 * `updateProfile`/`deleteAccount` are ported alongside it (and covered by
 * the ported `profile_repository_test.dart` cases) for the Settings screen
 * to reuse once it lands.
 */
import { toDateOnlyString } from '@/features/auth/api/auth-service';
import { supabase } from '@/platform/supabase/client';

import { parseCustomerProfile, type CustomerProfile } from './customer-profile';

type SupabaseResult<T> = { data: T | null; error: unknown };

/**
 * The slice of `supabase` {@link SupabaseProfileRepository} depends on,
 * narrowed the same way `activity-repository.ts`'s `ActivitySource` narrows
 * its own -- lets a test inject `src/test-utils/fake-supabase-client.ts`
 * (plus a plain `auth.getSession` stub) instead of the real client.
 */
export interface ProfileSource {
  auth: {
    getSession(): Promise<{ data: { session: { user: { id: string } } | null } }>;
  };
  from(table: 'profiles'): {
    select(columns: string): {
      eq(
        column: 'id',
        value: string,
      ): {
        maybeSingle(): PromiseLike<SupabaseResult<Record<string, unknown>>>;
      };
    };
  };
  rpc(
    fn: string,
    params?: Record<string, unknown>,
  ): PromiseLike<SupabaseResult<unknown>> & {
    single(): PromiseLike<SupabaseResult<Record<string, unknown>>>;
  };
}

/** Mirrors the Dart `StateError` every method throws before touching the network when no one is signed in. */
export class ProfileSignInRequiredError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ProfileSignInRequiredError';
  }
}

/** The fields {@link ProfileRepository.updateProfile} can write; an omitted (`undefined`) field leaves that column unchanged. */
export interface ProfileUpdate {
  firstName?: string;
  lastName?: string;
  phone?: string;
  dob?: Date;
}

export interface ProfileRepository {
  /** The signed-in customer's own profile, or `null` when no `profiles` row exists. */
  fetchCurrentProfile(): Promise<CustomerProfile | null>;

  /**
   * Writes whichever {@link ProfileUpdate} fields are provided via the
   * `update_own_profile` `security definer` RPC (`profiles` has no
   * `UPDATE` RLS policy a direct `.update()` could satisfy) and returns
   * the row as saved. The RPC derives the target row from `auth.uid()`
   * server-side, never from a caller-supplied id.
   */
  updateProfile(update: ProfileUpdate): Promise<CustomerProfile>;

  /**
   * Permanently deletes (anonymizes) the signed-in customer's own account
   * via the parameterless `delete_own_account` RPC. Callers must sign the
   * user out immediately after this succeeds.
   */
  deleteAccount(): Promise<void>;
}

export class SupabaseProfileRepository implements ProfileRepository {
  private readonly client: ProfileSource;

  constructor(client: ProfileSource = supabase as unknown as ProfileSource) {
    this.client = client;
  }

  async fetchCurrentProfile(): Promise<CustomerProfile | null> {
    const profileId = await this.currentUserId('Sign in before loading a customer profile.');
    const { data, error } = await this.client
      .from('profiles')
      .select('id, firstname, lastname, phone, avatar_url, dob')
      .eq('id', profileId)
      .maybeSingle();
    if (error) throw error;
    return data == null ? null : parseCustomerProfile(data);
  }

  async updateProfile(update: ProfileUpdate): Promise<CustomerProfile> {
    await this.currentUserId('Sign in before updating a customer profile.');
    // Mirrors the Dart `?firstName` null-aware map entries: only provided
    // fields are sent, so the RPC leaves every other column untouched.
    const params: Record<string, string> = {};
    if (update.firstName !== undefined) params.p_firstname = update.firstName;
    if (update.lastName !== undefined) params.p_lastname = update.lastName;
    if (update.phone !== undefined) params.p_phone = update.phone;
    if (update.dob !== undefined) params.p_dob = toDateOnlyString(update.dob);

    const { data, error } = await this.client.rpc('update_own_profile', params).single();
    if (error) throw error;
    if (data == null) throw new Error('update_own_profile returned no row.');
    return parseCustomerProfile(data);
  }

  async deleteAccount(): Promise<void> {
    await this.currentUserId('Sign in before deleting your account.');
    // No params: the RPC is security definer and scopes itself to
    // auth.uid() server-side, so there is nothing for the client to pass.
    const { error } = await this.client.rpc('delete_own_account');
    if (error) throw error;
  }

  private async currentUserId(signedOutMessage: string): Promise<string> {
    const {
      data: { session },
    } = await this.client.auth.getSession();
    const userId = session?.user.id;
    if (!userId) {
      throw new ProfileSignInRequiredError(signedOutMessage);
    }
    return userId;
  }
}
