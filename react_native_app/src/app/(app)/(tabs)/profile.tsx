/**
 * Ports `flutter_app/lib/features/profile/presentation/profile_screen.dart`
 * (issue #399 / P8-03): the bottom-nav Profile tab -- the customer's
 * identity header, the Account options card, and Logout.
 *
 * Same options as the Dart screen: Notifications (routes to Settings, which
 * owns the real notification toggles), Help & Support, and Settings.
 * Coupons & Offers was removed in Flutter (no coupons feature exists), and
 * Addresses/Wallet are hidden while delivery addresses and payments are out
 * of scope (owner decision, 2026-09-25) -- none of them are rendered here.
 * `/settings` and `/support` are still route placeholders in this app;
 * these rows push to them anyway, so they light up once those screens land.
 *
 * `profileRepository`/`auth` props are this screen's test seams, mirroring
 * the Dart `profileRepository` constructor parameter (and `explore.tsx`'s
 * `storeListingLoader` prop pattern).
 */
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, ScrollView, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { SectionTitle } from '@/components/section-title';
import { describeAuthError } from '@/features/auth/api/auth-error-message';
import { authService } from '@/features/auth/api/auth-service';
import { DEFAULT_CUSTOMER_DISPLAY_NAME, customerDisplayName, type CustomerProfile } from '@/features/profile/api/customer-profile';
import { SupabaseProfileRepository, type ProfileRepository } from '@/features/profile/api/profile-repository';
import { ProfileHeader } from '@/features/profile/profile-header';
import type { ProfileOption } from '@/features/profile/profile-option';
import { LogoutCard, ProfileOptionsCard } from '@/features/profile/profile-options-card';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { spacing } from '@/theme/tokens';

/** The slice of `AuthService` this screen needs -- just logout. */
export interface ProfileSignOut {
  signOut(): Promise<void>;
}

export type ProfileScreenProps = {
  /** Defaults to a {@link SupabaseProfileRepository} on the shared client. */
  profileRepository?: ProfileRepository;
  /** Defaults to the app-wide `authService`. */
  auth?: ProfileSignOut;
};

/** Mirrors the Dart screen's `_accountOptions`. */
const ACCOUNT_OPTIONS: readonly ProfileOption[] = [
  { title: 'Notifications', icon: 'notifications-none', route: AppRoutes.settings },
  { title: 'Help & Support', icon: 'help-outline', route: AppRoutes.support },
  { title: 'Settings', icon: 'settings', route: AppRoutes.settings },
];

type ProfileState = { status: 'loading' } | { status: 'done'; profile: CustomerProfile | null };

export default function ProfileScreen({ profileRepository, auth = authService }: ProfileScreenProps = {}) {
  const [state, setState] = useState<ProfileState>({ status: 'loading' });
  const isMounted = useRef(true);
  const reloadOnFocus = useRef(false);

  // Mirrors `_loadProfile`: any failure (including building the default
  // repository) falls back to the "Zivo customer" empty state, but is
  // reported rather than silently swallowed (Flutter issue #40).
  const loadProfile = useCallback(() => {
    Promise.resolve()
      .then(() => (profileRepository ?? new SupabaseProfileRepository()).fetchCurrentProfile())
      .catch((error: unknown) => {
        ErrorReporting.instance.reportError(
          error,
          error instanceof Error ? error.stack : undefined,
          'ProfileScreen.loadProfile',
        );
        return null;
      })
      .then((profile) => {
        if (isMounted.current) setState({ status: 'done', profile });
      });
  }, [profileRepository]);

  useEffect(() => {
    isMounted.current = true;
    loadProfile();
    return () => {
      isMounted.current = false;
    };
  }, [loadProfile]);

  // Mirrors `_handleOptionTap`'s reload after `await context.push(route)`
  // returns from Settings (where profile editing lives): Expo Router's
  // `push` doesn't resolve on return, so this reloads on the next focus
  // instead, and only after a trip through Settings.
  useFocusEffect(
    useCallback(() => {
      if (!reloadOnFocus.current) return;
      reloadOnFocus.current = false;
      setState({ status: 'loading' });
      loadProfile();
    }, [loadProfile]),
  );

  const handleOptionPress = useCallback((option: ProfileOption) => {
    if (option.route === undefined) return;
    if (option.route === AppRoutes.settings) reloadOnFocus.current = true;
    router.push(option.route);
  }, []);

  const handleLogout = useCallback(async () => {
    try {
      await auth.signOut();
      router.replace(AppRoutes.login);
    } catch (error) {
      const message = describeAuthError(error, 'Logout');
      Alert.alert(`Could not log out: ${message}`);
    }
  }, [auth]);

  const profile = state.status === 'done' ? state.profile : null;

  return (
    <AppScaffold title="Profile" showBackButton={false}>
      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: spacing.x5,
          paddingTop: spacing.x5,
          paddingBottom: spacing.x6,
        }}>
        <ProfileHeader
          displayName={profile ? customerDisplayName(profile) : DEFAULT_CUSTOMER_DISPLAY_NAME}
          contactLabel={profile && profile.phone !== '' ? profile.phone : 'Somalia • USD'}
          isLoading={state.status === 'loading'}
        />
        <View style={{ height: spacing.sectionGap }} />
        <SectionTitle title="Account" />
        <View style={{ height: spacing.headerToContent }} />
        <ProfileOptionsCard options={ACCOUNT_OPTIONS} onOptionPress={handleOptionPress} />
        <View style={{ height: spacing.x4 }} />
        <LogoutCard onPress={handleLogout} />
      </ScrollView>
    </AppScaffold>
  );
}
