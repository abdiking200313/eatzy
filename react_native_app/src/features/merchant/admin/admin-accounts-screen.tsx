import { EmptyState } from '@/components/empty-state';

export type AdminAccountsScreenProps = {
  /** The signed-in admin's `profiles.id` (Flutter uses it to stop an admin demoting themselves). Unused until the Accounts screen is ported. */
  currentUserId: string;
};

/**
 * Placeholder for `flutter_app/lib/features/merchant/admin/presentation/
 * admin_accounts_screen.dart`'s `AdminAccountsScreen` (the admin-only
 * role-management list, backed by the `admin_list_profiles`/
 * `admin_set_profile_role` RPCs). No migration issue covers porting it yet;
 * the merchant shell (P9-01, #406) only needs the admin branch to land
 * somewhere instead of on the merchant destinations.
 */
export function AdminAccountsScreen(_props: AdminAccountsScreenProps) {
  return (
    <EmptyState
      icon="manage-accounts"
      title="Account management is coming soon"
      message="You'll be able to review accounts and change their roles here."
    />
  );
}
