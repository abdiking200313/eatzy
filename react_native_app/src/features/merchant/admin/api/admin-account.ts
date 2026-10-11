/**
 * Ports `flutter_app/lib/features/merchant/admin/models/admin_account.dart`
 * (issue #412 / P9-07): one row of `admin_list_profiles` (see
 * `supabase/migrations/20260922000000_add_admin_list_profiles_rpc.sql`) --
 * what the admin "Accounts" list shows for each account, and enough to
 * change its role.
 */
export interface AdminAccount {
  /** `profiles.id` (== `auth.uid()`). */
  id: string;
  firstName: string;
  lastName: string;
  /** The account's sign-up email (`auth.users.email`); empty when the account has none. */
  email: string;
  /** Current `profiles.role`: `customer`, `merchant`, or `admin`. */
  role: string;
}

/** The roles an admin can assign, in the order the role picker lists them. */
export const ADMIN_ASSIGNABLE_ROLES = ['customer', 'merchant', 'admin'] as const;

/** Mirrors the Dart `displayName` getter: full name, else email, else id. */
export function adminAccountDisplayName(account: AdminAccount): string {
  const name = `${account.firstName} ${account.lastName}`.trim();
  if (name.length > 0) return name;
  return account.email.length === 0 ? account.id : account.email;
}

function stringOrEmpty(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** Mirrors the Dart `AdminAccount.fromMap`: null name/email become `''`. */
export function adminAccountFromRow(row: Record<string, unknown>): AdminAccount {
  return {
    id: String(row.id),
    firstName: stringOrEmpty(row.firstname),
    lastName: stringOrEmpty(row.lastname),
    email: stringOrEmpty(row.email),
    role: String(row.role),
  };
}
