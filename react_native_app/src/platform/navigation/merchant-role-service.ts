/**
 * Ports `flutter_app/lib/features/merchant/auth/data/merchant_role_service.dart`
 * (issue #363).
 *
 * `isAuthorizedMerchantRole` is kept pure and separate from
 * {@link MerchantRoleService}, exactly like the Flutter original, so the
 * routing predicate itself is unit-testable with no Supabase dependency --
 * `src/stores/merchant-session-gate.ts` (this app's `MerchantSessionGate`
 * port) is the only caller of {@link MerchantRoleService.fetchRole} in
 * normal operation.
 */
import { supabase } from '@/platform/supabase/client';

/**
 * `profiles.role` values that route a signed-in account to the merchant
 * dashboard instead of the customer home. Matches the exact set from
 * `profiles_role_check` in
 * `supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql`
 * (`'customer' | 'merchant' | 'admin'`, default `'customer'`) -- only
 * `merchant` and `admin` land on the merchant dashboard.
 */
export const kAllowedMerchantRoles: ReadonlySet<string> = new Set(['merchant', 'admin']);

/**
 * Pure role-gating predicate: `merchant`/`admin` route to the merchant
 * dashboard, `customer`, any other string, and `null` (no profile row, or
 * the lookup failed) all route to the ordinary customer home.
 */
export function isAuthorizedMerchantRole(role: string | null): boolean {
  return role != null && kAllowedMerchantRoles.has(role);
}

/**
 * The slice of `supabase` {@link MerchantRoleService} depends on, narrowed
 * the same way `session-store.ts`'s `AuthStateSource` / `password-
 * recovery.ts`'s `PasswordRecoverySessionSource` narrow their own Supabase
 * dependencies -- lets a test inject a fake (e.g.
 * `src/test-utils/fake-supabase-client.ts`) instead of the real client.
 */
export interface ProfileRoleSource {
  from(table: 'profiles'): {
    select(columns: 'role'): {
      eq(
        column: 'id',
        value: string,
      ): {
        maybeSingle(): PromiseLike<{ data: { role: string | null } | null; error: unknown }>;
      };
    };
  };
}

export interface MerchantRoleServiceOptions {
  client?: ProfileRoleSource;
}

/**
 * Looks up the signed-in user's `profiles.role`, used by
 * `merchant-session-gate.ts` right after a successful sign-in and again on
 * session-restore at app start to decide whether the account lands on the
 * merchant dashboard or the normal customer home. This intentionally does
 * not perform its own sign-in/sign-out -- the main app's own session store
 * remains the only sign-in flow; this only answers "which home screen".
 */
export class MerchantRoleService {
  private readonly client: ProfileRoleSource;

  constructor(options: MerchantRoleServiceOptions = {}) {
    this.client = options.client ?? (supabase as unknown as ProfileRoleSource);
  }

  /**
   * Returns the current `profiles.role` for `userId`, or `null` if no
   * profile row exists or the lookup fails. A failure is treated the same
   * as "no role found" by callers (see {@link isAuthorizedMerchantRole})
   * rather than thrown, so a transient network error at sign-in/session-
   * restore time fails closed into the customer experience instead of
   * blocking startup or login.
   */
  async fetchRole(userId: string): Promise<string | null> {
    try {
      const { data, error } = await this.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
      if (error) {
        return null;
      }
      return data?.role ?? null;
    } catch {
      return null;
    }
  }

  /** Convenience combining {@link fetchRole} with {@link isAuthorizedMerchantRole}. */
  async isMerchantAccount(userId: string): Promise<boolean> {
    return isAuthorizedMerchantRole(await this.fetchRole(userId));
  }
}
