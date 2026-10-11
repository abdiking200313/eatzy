/**
 * Ports `flutter_app/lib/features/merchant/shell/presentation/
 * merchant_shell.dart`'s `MerchantShell` (issue #406 / P9-01): the merchant
 * dashboard's post-sign-in navigation shell.
 *
 * - A plain `merchant` account gets an app bar titled "Zivo Merchant" with a
 *   "Sign out" action, and a bottom nav with "My Store" and "Orders".
 * - An `admin` account (`useMerchantSessionGateStore`'s `isAdmin`) sees none
 *   of that: only the "Accounts" role-management screen plus sign-out, under
 *   a "Zivo Admin" title, with no bottom nav.
 * - With no signed-in user at all (the session ended between the
 *   `merchant/_layout.tsx` gate and this render) it shows a "session ended"
 *   prompt instead, like the Dart `_SignedOutView`.
 *
 * Both merchant destinations stay mounted while switching tabs (hidden with
 * `display: 'none'`), mirroring the Dart `IndexedStack`, so each keeps its
 * own state across tab switches.
 *
 * Like the Dart shell, it owns one `MerchantStoreController` shared by both
 * destinations (P9-03, #408) so "my store" is only resolved once -- and a
 * store created from "My Store" shows up on "Orders" straight away.
 *
 * `ownerId`/`isAdmin`/`auth` are this component's test seams, mirroring the
 * Dart constructor's `ownerId`/`isAdmin`/`authService` parameters.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useCallback, useMemo, useState, type ComponentProps } from 'react';
import { Alert, Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppScaffold } from '@/components/app-scaffold';
import { PrimaryButton } from '@/components/primary-button';
import { describeAuthError } from '@/features/auth/api/auth-error-message';
import { authService } from '@/features/auth/api/auth-service';
import { AdminAccountsScreen } from '@/features/merchant/admin/admin-accounts-screen';
import { OrdersScreen } from '@/features/merchant/orders/orders-screen';
import { MerchantStoreController } from '@/features/merchant/store/merchant-store-controller';
import { MyStoreScreen } from '@/features/merchant/store/my-store-screen';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { useMerchantSessionGateStore } from '@/stores/merchant-session-gate';
import { useSessionStore } from '@/stores/session-store';
import { maxFontScale, spacing } from '@/theme/tokens';

/** The slice of `AuthService` this shell needs -- just sign-out. */
export interface MerchantShellSignOut {
  signOut(): Promise<void>;
}

export type MerchantShellProps = {
  /** The signed-in merchant's `profiles.id`. Defaults to the session store's `userId`. */
  ownerId?: string | null;
  /** Whether to show the admin-only Accounts screen instead of the merchant destinations. Defaults to the merchant-session gate's `isAdmin`. */
  isAdmin?: boolean;
  /** Defaults to the app-wide `authService`. */
  auth?: MerchantShellSignOut;
};

type Destination = {
  label: string;
  /** Stable selector for tests and Maestro E2E flows (`e2e/merchant-order.yaml`). */
  testID: string;
  icon: ComponentProps<typeof MaterialIcons>['name'];
};

/** Mirrors the Dart `NavigationBar`'s two destinations (`Icons.storefront_*` / `Icons.receipt_long_*`). */
const DESTINATIONS: readonly Destination[] = [
  { label: 'My Store', testID: 'merchant-nav-store', icon: 'storefront' },
  { label: 'Orders', testID: 'merchant-nav-orders', icon: 'receipt-long' },
];

export function MerchantShell({ ownerId: ownerIdProp, isAdmin: isAdminProp, auth = authService }: MerchantShellProps = {}) {
  const sessionUserId = useSessionStore((state) => state.userId);
  const gateIsAdmin = useMerchantSessionGateStore((state) => state.isAdmin);
  const ownerId = ownerIdProp === undefined ? sessionUserId : ownerIdProp;
  const isAdmin = isAdminProp ?? gateIsAdmin;

  const [selectedIndex, setSelectedIndex] = useState(0);
  // Shared by "My Store" and "Orders" (the Dart shell's `_storeController`);
  // a different signed-in owner gets a fresh one.
  const storeController = useMemo(() => (ownerId == null ? null : new MerchantStoreController()), [ownerId]);

  const handleSignOut = useCallback(async () => {
    try {
      await auth.signOut();
      router.replace(AppRoutes.login);
    } catch (error) {
      Alert.alert(`Could not sign out: ${describeAuthError(error, 'MerchantShell.signOut')}`);
    }
  }, [auth]);

  if (ownerId == null || storeController == null) {
    return <SignedOutView onSignIn={() => router.replace(AppRoutes.login)} />;
  }

  return (
    <AppScaffold
      title={isAdmin ? 'Zivo Admin' : 'Zivo Merchant'}
      actions={<SignOutButton onPress={() => void handleSignOut()} />}
      bottomBar={
        isAdmin ? undefined : (
          <MerchantNavigationBar selectedIndex={selectedIndex} onSelect={setSelectedIndex} />
        )
      }>
      {isAdmin ? (
        <AdminAccountsScreen currentUserId={ownerId} />
      ) : (
        <>
          <View style={{ flex: 1, display: selectedIndex === 0 ? 'flex' : 'none' }}>
            <MyStoreScreen ownerId={ownerId} controller={storeController} />
          </View>
          <View style={{ flex: 1, display: selectedIndex === 1 ? 'flex' : 'none' }}>
            <OrdersScreen ownerId={ownerId} storeController={storeController} />
          </View>
        </>
      )}
    </AppScaffold>
  );
}

/** Mirrors the Dart app bar's `IconButton(tooltip: 'Sign out', icon: Icons.logout_rounded)`. */
function SignOutButton({ onPress }: { onPress: () => void }) {
  const colors = useSemanticColors();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Sign out"
      onPress={onPress}
      className="h-x10 w-x10 items-center justify-center active:opacity-70">
      <MaterialIcons name="logout" size={24} color={colors.text} />
    </Pressable>
  );
}

/**
 * The merchant bottom nav. Styled like the customer shell's `MainAppTabBar`
 * (`src/app/(app)/(tabs)/_layout.tsx`): icon + label, tinted
 * `primary`/`textMuted` for selected/unselected, no selection pill.
 */
function MerchantNavigationBar({ selectedIndex, onSelect }: { selectedIndex: number; onSelect: (index: number) => void }) {
  const colors = useSemanticColors();
  return (
    <SafeAreaView edges={['bottom']} style={{ backgroundColor: colors.white, borderTopWidth: 1, borderTopColor: colors.border }}>
      <View accessibilityRole="tablist" style={{ flexDirection: 'row', height: spacing.navBarContentHeight }}>
        {DESTINATIONS.map((destination, index) => {
          const isSelected = index === selectedIndex;
          const tintColor = isSelected ? colors.primary : colors.textMuted;
          return (
            <Pressable
              key={destination.label}
              testID={destination.testID}
              accessibilityRole="tab"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={destination.label}
              onPress={() => onSelect(index)}
              style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
              <MaterialIcons name={destination.icon} size={24} color={tintColor} />
              <Text
                style={{ marginTop: 2 }}
                // The bar is a fixed `navBarContentHeight` tall: cap large
                // accessibility text sizes so labels can't overflow it (the
                // tab's accessibilityLabel still carries the full name).
                maxFontSizeMultiplier={maxFontScale.navLabel}
                numberOfLines={1}
                className={isSelected ? 'text-textXs font-outfitBold text-primary' : 'text-textXs font-outfitMedium text-textMuted'}>
                {destination.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </SafeAreaView>
  );
}

/** Mirrors the Dart `_SignedOutView`: a safe fallback when there is no signed-in user, not an expected steady state. */
function SignedOutView({ onSignIn }: { onSignIn: () => void }) {
  const colors = useSemanticColors();
  return (
    <View style={{ flex: 1, backgroundColor: colors.bg, alignItems: 'center', justifyContent: 'center', padding: spacing.x6 }}>
      <MaterialIcons name="lock-outline" size={48} color={colors.textMuted} />
      <Text style={{ marginTop: spacing.x4 }} className="text-center font-outfitBold text-text">
        Your session has ended
      </Text>
      <Text style={{ marginTop: spacing.x1 }} className="text-center font-outfitRegular text-text">
        Sign in again to get back to your store.
      </Text>
      <View style={{ marginTop: spacing.x6 }}>
        <PrimaryButton label="Sign in" onPress={onSignIn} fullWidth={false} />
      </View>
    </View>
  );
}
