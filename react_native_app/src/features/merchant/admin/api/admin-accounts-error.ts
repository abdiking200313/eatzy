/**
 * Mirrors the Dart `AdminAccountsException`
 * (`flutter_app/lib/features/merchant/admin/data/admin_accounts_repository.dart`):
 * `admin_list_profiles`/`admin_set_profile_role` rejected the call (caller
 * isn't an admin, invalid role, unknown profile, or demoting the last
 * remaining admin). `message` is the RPC's own `raise exception` text, shown
 * to the admin verbatim.
 *
 * Its own module (like `order-status-transition-error.ts`) so test fakes can
 * import it without pulling in the real Supabase client.
 */
export class AdminAccountsError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdminAccountsError';
  }
}
