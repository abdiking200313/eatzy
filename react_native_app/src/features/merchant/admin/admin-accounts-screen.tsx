/**
 * Ports `flutter_app/lib/features/merchant/admin/presentation/admin_accounts_screen.dart`
 * (issue #412 / P9-07): the admin-only "Accounts" screen -- a searchable,
 * paginated list of every account with its name, email and a role picker.
 * Picking a different role asks for confirmation, then saves via
 * `admin_set_profile_role`; the result is shown in a snackbar.
 *
 * It is the only thing an admin sees in `MerchantShell`, but the actual
 * authorization is enforced server-side by the `admin_list_profiles` /
 * `admin_set_profile_role` RPCs, not by this screen being hard to reach.
 *
 * RN adaptations of Dart widgets with no direct RN counterpart:
 * - `DropdownButton` -> a pressable "dropdown" (`testID="role-<id>"`) that
 *   opens a small menu of roles in a transparent `Modal`.
 * - `AlertDialog` -> the platform `Alert.alert` with Cancel/Confirm buttons.
 * - `ScaffoldMessenger` snackbar -> `useCartSnackbar` + `CartSnackbar`.
 * - The scroll-position "load more" threshold -> `FlatList.onEndReached`.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Modal, Pressable, Text, View } from 'react-native';

import { AppSearchBar } from '@/components/app-search-bar';
import { CartSnackbar } from '@/components/cart-snackbar';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { OutlinedCard } from '@/components/outlined-card';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, spacing } from '@/theme/tokens';

import { ADMIN_ASSIGNABLE_ROLES, adminAccountDisplayName, type AdminAccount } from './api/admin-account';
import { ADMIN_ACCOUNTS_PAGE_SIZE, AdminAccountsController, useAdminAccountsState, type AdminAccountsState } from './admin-accounts-controller';

export type AdminAccountsScreenProps = {
  /**
   * The signed-in admin's own `profiles.id`. Their row's role picker is
   * disabled so an admin can't strand themselves by demoting the account
   * they are using.
   */
  currentUserId: string;
  /** Overridable for tests; defaults to a Supabase-backed controller. */
  controller?: AdminAccountsController;
};

/** The Dart `_searchDebounce`. */
export const ADMIN_SEARCH_DEBOUNCE_MS = 350;

/** Mirrors the Dart `_label`: capitalizes the role's first letter. */
export function roleLabel(role: string): string {
  return role.length === 0 ? role : `${role[0].toUpperCase()}${role.slice(1)}`;
}

function confirmationMessage(account: AdminAccount, newRole: string): string {
  const name = adminAccountDisplayName(account);
  return newRole === 'admin'
    ? `${name} will be able to manage every account's role, including granting or removing other admins.`
    : `This changes ${name} from ${account.role} to ${newRole}.`;
}

export function AdminAccountsScreen({ currentUserId, controller: controllerProp }: AdminAccountsScreenProps) {
  const [ownController] = useState(() => (controllerProp ? null : new AdminAccountsController()));
  const controller = controllerProp ?? ownController!;
  const state = useAdminAccountsState(controller);
  const snackbar = useCartSnackbar();
  const colors = useSemanticColors();

  const [search, setSearch] = useState('');
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    void controller.load();
  }, [controller]);

  useEffect(
    () => () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    },
    [],
  );

  const onSearchChanged = useCallback(
    (value: string) => {
      setSearch(value);
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => void controller.load(value), ADMIN_SEARCH_DEBOUNCE_MS);
    },
    [controller],
  );

  const changeRole = useCallback(
    async (account: AdminAccount, newRole: string) => {
      const succeeded = await controller.setRole(account.id, newRole);
      snackbar.show(
        succeeded
          ? `${adminAccountDisplayName(account)} is now ${newRole}.`
          : (controller.saveError ?? 'The role could not be changed.'),
      );
    },
    [controller, snackbar],
  );

  const confirmRoleChange = useCallback(
    (account: AdminAccount, newRole: string) => {
      Alert.alert(`Change ${adminAccountDisplayName(account)}'s role?`, confirmationMessage(account, newRole), [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Confirm', onPress: () => void changeRole(account, newRole) },
      ]);
    },
    [changeRole],
  );

  return (
    <View className="relative flex-1">
      <View style={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x4, paddingBottom: spacing.x2 }}>
        <Text accessibilityRole="header" className="text-textLg font-outfitBold text-text">
          Accounts
        </Text>
        <Text style={{ marginTop: spacing.x1, color: colors.textMuted }} className="text-textSm font-outfitRegular">
          Change what each account can do. Customers shop, merchants run a store, admins manage accounts.
        </Text>
        <View style={{ marginTop: spacing.x3 }}>
          <AppSearchBar hintText="Search by name or email" value={search} onChangeText={onSearchChanged} />
        </View>
      </View>
      <View className="flex-1">
        <AccountsBody
          state={state}
          controller={controller}
          currentUserId={currentUserId}
          onPickRole={confirmRoleChange}
        />
      </View>
      <CartSnackbar message={snackbar.message} />
    </View>
  );
}

type AccountsBodyProps = {
  state: AdminAccountsState;
  controller: AdminAccountsController;
  currentUserId: string;
  onPickRole: (account: AdminAccount, newRole: string) => void;
};

function AccountsBody({ state, controller, currentUserId, onPickRole }: AccountsBodyProps) {
  const colors = useSemanticColors();
  const { accounts } = state;

  if (state.isLoading && accounts.length === 0) {
    return <LoadingState />;
  }
  if (state.loadError != null) {
    return <ErrorState message={state.loadError} onRetry={() => void controller.load(state.query)} />;
  }
  if (accounts.length === 0) {
    return (
      <EmptyState
        icon="manage-accounts"
        title={state.query.length === 0 ? 'No accounts yet.' : `No accounts match "${state.query}".`}
      />
    );
  }

  const showFooter = state.hasMore || state.isLoadingMore || state.loadMoreError != null;

  return (
    <View className="flex-1">
      {state.isLoading ? <ActivityIndicator testID="admin-accounts-refreshing" color={colors.primary} /> : null}
      <FlatList
        testID="admin-accounts-list"
        data={accounts}
        keyExtractor={(account) => account.id}
        // One full page up front, so a freshly loaded page is never half-virtualized away.
        initialNumToRender={ADMIN_ACCOUNTS_PAGE_SIZE}
        contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x2, paddingBottom: spacing.x4 }}
        onEndReached={() => void controller.loadMore()}
        onEndReachedThreshold={0.5}
        renderItem={({ item }) => (
          <AccountCard
            account={item}
            isSelf={item.id === currentUserId}
            isSaving={state.savingId === item.id}
            pickerDisabled={item.id === currentUserId || state.isSaving}
            onPickRole={onPickRole}
          />
        )}
        ListFooterComponent={showFooter ? <ListFooter state={state} onLoadMore={() => void controller.loadMore()} /> : null}
      />
    </View>
  );
}

function ListFooter({ state, onLoadMore }: { state: AdminAccountsState; onLoadMore: () => void }) {
  const colors = useSemanticColors();
  if (state.isLoadingMore) {
    return (
      <View style={{ paddingVertical: spacing.x4 }}>
        <ActivityIndicator testID="admin-accounts-loading-more" color={colors.primary} />
      </View>
    );
  }
  return (
    <View style={{ paddingVertical: spacing.x2 }} className="items-center">
      {state.loadMoreError != null ? (
        <Text style={{ marginBottom: spacing.x1, color: colors.error }} className="text-center text-textSm font-outfitRegular">
          {state.loadMoreError}
        </Text>
      ) : null}
      <Pressable accessibilityRole="button" onPress={onLoadMore} style={{ padding: spacing.x2 }} className="active:opacity-70">
        <Text style={{ color: colors.primary }} className="text-textSm font-outfitSemiBold">
          {state.loadMoreError != null ? 'Try again' : 'Load more'}
        </Text>
      </Pressable>
    </View>
  );
}

type AccountCardProps = {
  account: AdminAccount;
  isSelf: boolean;
  isSaving: boolean;
  pickerDisabled: boolean;
  onPickRole: (account: AdminAccount, newRole: string) => void;
};

function AccountCard({ account, isSelf, isSaving, pickerDisabled, onPickRole }: AccountCardProps) {
  const colors = useSemanticColors();
  return (
    <View style={{ marginBottom: spacing.x3 }}>
      <OutlinedCard padding={spacing.x4} testID={`admin-account-${account.id}`}>
        <View className="flex-row items-center">
          <View className="flex-1" style={{ marginRight: spacing.x3 }}>
            <View className="flex-row items-center">
              <Text numberOfLines={1} className="shrink text-fontBoldBase font-outfitSemiBold text-text">
                {adminAccountDisplayName(account)}
              </Text>
              {isSelf ? (
                <Text style={{ marginLeft: spacing.x2, color: colors.textMuted }} className="text-textXs font-outfitMedium">
                  You
                </Text>
              ) : null}
            </View>
            {account.email.length > 0 ? (
              <Text numberOfLines={1} style={{ marginTop: 3, color: colors.textMuted }} className="text-textSm font-outfitRegular">
                {account.email}
              </Text>
            ) : null}
          </View>
          {isSaving ? (
            <ActivityIndicator testID={`role-saving-${account.id}`} color={colors.primary} />
          ) : (
            <RolePicker
              account={account}
              disabled={pickerDisabled}
              onPick={(role) => {
                if (role !== account.role) onPickRole(account, role);
              }}
            />
          )}
        </View>
      </OutlinedCard>
    </View>
  );
}

/**
 * Stand-in for the Dart `DropdownButton<String>`: shows the current role and
 * opens a menu of roles. Controlled by `account.role`, so cancelling the
 * confirmation needs no revert -- the picker never moved. An unrecognized
 * current role is still listed, as in Dart.
 */
function RolePicker({ account, disabled, onPick }: { account: AdminAccount; disabled: boolean; onPick: (role: string) => void }) {
  const colors = useSemanticColors();
  const [open, setOpen] = useState(false);
  const roles: readonly string[] = (ADMIN_ASSIGNABLE_ROLES as readonly string[]).includes(account.role)
    ? ADMIN_ASSIGNABLE_ROLES
    : [...ADMIN_ASSIGNABLE_ROLES, account.role];

  return (
    <>
      <Pressable
        testID={`role-${account.id}`}
        accessibilityRole="button"
        accessibilityLabel={`Role: ${roleLabel(account.role)}`}
        accessibilityState={{ disabled }}
        disabled={disabled}
        onPress={() => setOpen(true)}
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          paddingHorizontal: spacing.x3,
          paddingVertical: spacing.x2,
          borderRadius: radius.control,
          borderWidth: 1,
          borderColor: colors.border,
          opacity: disabled ? 0.5 : 1,
        }}>
        <Text className="text-textSm font-outfitMedium text-text">{roleLabel(account.role)}</Text>
        <MaterialIcons name="arrow-drop-down" size={20} color={colors.textMuted} />
      </Pressable>
      <Modal visible={open} transparent animationType="fade" onRequestClose={() => setOpen(false)}>
        <Pressable
          accessibilityLabel="Close role menu"
          onPress={() => setOpen(false)}
          style={{ flex: 1, backgroundColor: 'rgba(15, 23, 42, 0.4)', alignItems: 'center', justifyContent: 'center', padding: spacing.x6 }}>
          <View
            accessibilityRole="menu"
            style={{ backgroundColor: colors.card, borderRadius: radius.card, paddingVertical: spacing.x2, minWidth: 220 }}>
            {roles.map((role) => {
              const isCurrent = role === account.role;
              return (
                <Pressable
                  key={role}
                  testID={`role-option-${account.id}-${role}`}
                  accessibilityRole="menuitem"
                  accessibilityState={{ selected: isCurrent }}
                  onPress={() => {
                    setOpen(false);
                    onPick(role);
                  }}
                  style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: spacing.x4, paddingVertical: spacing.x3 }}>
                  <Text style={{ flex: 1 }} className={isCurrent ? 'font-outfitBold text-primary' : 'font-outfitRegular text-text'}>
                    {roleLabel(role)}
                  </Text>
                  {isCurrent ? <MaterialIcons name="check" size={18} color={colors.primary} /> : null}
                </Pressable>
              );
            })}
          </View>
        </Pressable>
      </Modal>
    </>
  );
}
