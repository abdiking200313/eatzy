/**
 * Ports `flutter_app/lib/features/settings/presentation/settings_screen.dart`
 * (issue #400 / P8-04): the Account section (Name / Phone Number / Date of
 * Birth / Email Address / Change Password, edited through
 * {@link ProfileEditController} and saved via `update_own_profile`), the
 * Preferences "Coming soon" rows, and the Support section (About sheet,
 * Privacy Policy, Terms & Conditions), plus the Notifications section
 * (#401 / P8-05): per-owner toggles persisted through
 * {@link NotificationPreferencesStorage}, with the Push toggle gated on OS
 * permission via {@link PushNotificationGateway}.
 *
 * The Logout / Delete Account danger zone (#402 / P8-06) ports
 * `_logout` and `_confirmDeleteAccount`: deletion is confirmed first, goes
 * through `delete_own_account` ({@link ProfileRepository.deleteAccount}),
 * then signs out. Clearing local per-account data (carts, activity, the
 * merchant gate) is not done here: the resulting `SIGNED_OUT` auth event
 * drives `session-store.ts` -> `AccountStateCoordinator` ->
 * `sessionResetRegistry`, exactly as Flutter's `main.dart` auth listener
 * does, and supabase-js's `signOut` drops the local session even when the
 * server call fails. Flutter's `AlertDialog` becomes the platform
 * `Alert.alert` (same precedent as `cart-view.tsx`'s clear-cart confirm).
 *
 * Flutter's `ScaffoldMessenger` snack bars become this screen's own
 * `CartSnackbar` + `useCartSnackbar` pair (the app's only snackbar host so
 * far); `showModalBottomSheet` becomes {@link SettingsSheet}.
 */
import DateTimePicker, { type DateTimePickerEvent } from '@react-native-community/datetimepicker';
import { router } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, ScrollView, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { CartSnackbar } from '@/components/cart-snackbar';
import { describeAuthError } from '@/features/auth/api/auth-error-message';
import { authService } from '@/features/auth/api/auth-service';
import type { CustomerProfile } from '@/features/profile/api/customer-profile';
import { customerDisplayName } from '@/features/profile/api/customer-profile';
import { SupabaseProfileRepository, type ProfileRepository } from '@/features/profile/api/profile-repository';
import {
  ProfileEditController,
  SAVE_FAILURE_MESSAGE,
  type ProfileEditResult,
  type ProfileEmailAuth,
} from '@/features/profile/profile-edit-controller';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { formatShortDate } from '@/platform/localization/date-format';
import { PushNotifications, type PushNotificationGateway } from '@/platform/notifications/push-notifications';
import { useSessionStore } from '@/stores/session-store';
import { spacing } from '@/theme/tokens';

import { AboutZivoSheet } from './about-zivo-sheet';
import { AccountDangerZone } from './account-danger-zone';
import {
  AsyncStorageNotificationPreferencesStorage,
  DEFAULT_NOTIFICATION_PREFERENCES,
  type NotificationPreferences,
  type NotificationPreferencesStorage,
} from './api/notification-preferences-repository';
import { EmailEditSheet, NameEditSheet, PhoneEditSheet } from './profile-edit-sheets';
import { AccountSection, NotificationsSection, PreferencesSection, SupportSection } from './settings-sections';
import { SettingsSheet } from './settings-sheet';

export const PROFILE_UPDATED_MESSAGE = 'Profile updated';
export const EMAIL_CHANGE_REQUESTED_MESSAGE = 'Check your new inbox to confirm your email change.';
export const PUSH_PERMISSION_BLOCKED_MESSAGE =
  'Notifications are blocked for Zivo. Enable them in your device settings to turn this on.';
export const DELETE_ACCOUNT_TITLE = 'Delete your account?';
export const DELETE_ACCOUNT_MESSAGE = "This permanently removes your profile and personal data. This can't be undone.";
const NOT_ADDED_YET = 'Not added yet';
const LOADING = 'Loading…';

/**
 * The default {@link ProfileEmailAuth}: the email comes off the session
 * store (supabase-js has no synchronous `currentSession` getter like the
 * Dart SDK's), and the change request goes through the app-wide
 * `authService`.
 */
const defaultEmailAuth: ProfileEmailAuth = {
  getCurrentUserEmail: () => useSessionStore.getState().session?.user.email ?? null,
  updateEmail: (email) => authService.updateEmail(email),
};

/** The slice of `AuthService` the danger zone needs -- just sign-out (same seam as the Profile tab's `ProfileSignOut`). */
export interface SettingsSignOut {
  signOut(): Promise<void>;
}

export type SettingsScreenProps = {
  /** Defaults to a {@link SupabaseProfileRepository} on the shared client. */
  profileRepository?: ProfileRepository;
  /** Defaults to the session store + app-wide `authService`. */
  emailAuth?: ProfileEmailAuth;
  /** Defaults to {@link AsyncStorageNotificationPreferencesStorage}. */
  notificationPreferencesStorage?: NotificationPreferencesStorage;
  /** Defaults to `PushNotifications.instance`. */
  pushNotificationGateway?: PushNotificationGateway;
  /**
   * The owner notification preferences are scoped to (Dart's
   * `AuthService.getCurrentUserId`). Defaults to the session store's
   * `userId`; `null` means signed out, so nothing is read or saved.
   */
  getCurrentUserId?: () => string | null;
  /** Defaults to the app-wide `authService`. */
  auth?: SettingsSignOut;
};

const defaultGetCurrentUserId = () => useSessionStore.getState().userId;

/** Mirrors `_readHasPushPermission`: a failure means "can't tell", not "denied". */
async function readHasPushPermission(gateway: PushNotificationGateway): Promise<boolean> {
  try {
    return await gateway.hasPermission();
  } catch {
    return true;
  }
}

function reportPreferencesError(error: unknown, context: string) {
  ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);
}

type ActiveSheet = 'name' | 'phone' | 'email' | 'about' | null;

/** Mirrors `_nameSubtitle`: checks first/last name directly so the "Zivo customer" display fallback never reads as a saved name. */
function nameSubtitle(profile: CustomerProfile | null): string {
  const hasName = profile != null && (profile.firstName !== '' || profile.lastName !== '');
  return hasName ? customerDisplayName(profile) : NOT_ADDED_YET;
}

function eighteenYearsAgo(now: Date): Date {
  return new Date(now.getFullYear() - 18, now.getMonth(), now.getDate());
}

export function SettingsScreen({
  profileRepository,
  emailAuth = defaultEmailAuth,
  notificationPreferencesStorage,
  pushNotificationGateway,
  getCurrentUserId = defaultGetCurrentUserId,
  auth = authService,
}: SettingsScreenProps = {}) {
  // Resolved once, like the Dart `didChangeDependencies` guard.
  const [repository] = useState<ProfileRepository>(() => profileRepository ?? new SupabaseProfileRepository());
  const [preferencesStorage] = useState<NotificationPreferencesStorage>(
    () => notificationPreferencesStorage ?? new AsyncStorageNotificationPreferencesStorage(),
  );
  const [pushGateway] = useState<PushNotificationGateway>(() => pushNotificationGateway ?? PushNotifications.instance);
  const [ownerId] = useState<string | null>(() => {
    try {
      return getCurrentUserId();
    } catch {
      return null;
    }
  });
  const [preferences, setPreferences] = useState<NotificationPreferences>(DEFAULT_NOTIFICATION_PREFERENCES);
  // Latest value for the toggle handlers, mirroring Dart's `_preferences`
  // field reads (state captured in a closure could be one toggle stale).
  const preferencesRef = useRef(preferences);
  const [controller] = useState(() => new ProfileEditController({ profileRepository: repository, emailAuth }));
  const [email] = useState<string | null>(() => {
    try {
      return emailAuth.getCurrentUserEmail();
    } catch {
      return null;
    }
  });
  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [profileLoading, setProfileLoading] = useState(true);
  const [activeSheet, setActiveSheet] = useState<ActiveSheet>(null);
  const [isDobPickerVisible, setIsDobPickerVisible] = useState(false);
  const { message: snackbarMessage, show: showSnackbar } = useCartSnackbar();
  const isMounted = useRef(true);

  useEffect(() => {
    isMounted.current = true;
    repository
      .fetchCurrentProfile()
      .catch(() => null)
      .then((loaded) => {
        if (!isMounted.current) return;
        setProfile(loaded);
        setProfileLoading(false);
      });
    return () => {
      isMounted.current = false;
    };
  }, [repository]);

  /** Mirrors `_loadPreferences`, including the stale push-on reconciliation. */
  useEffect(() => {
    if (ownerId == null) return;
    let cancelled = false;
    (async () => {
      let stored = await preferencesStorage.read(ownerId);
      // A saved "on" with no (or revoked) OS permission is shown and saved as off.
      if (stored.pushNotifications && !(await readHasPushPermission(pushGateway))) {
        stored = { ...stored, pushNotifications: false };
        await preferencesStorage.write(ownerId, stored);
      }
      if (cancelled) return;
      preferencesRef.current = stored;
      setPreferences(stored);
    })().catch((error: unknown) => reportPreferencesError(error, 'SettingsScreen.loadPreferences'));
    return () => {
      cancelled = true;
    };
  }, [ownerId, preferencesStorage, pushGateway]);

  /** Mirrors `_updatePreferences`: apply immediately, then persist without blocking the toggle. */
  const updatePreferences = useCallback(
    async (next: NotificationPreferences) => {
      preferencesRef.current = next;
      setPreferences(next);
      if (ownerId == null) return;
      try {
        await preferencesStorage.write(ownerId, next);
      } catch (error) {
        reportPreferencesError(error, 'SettingsScreen.updatePreferences');
      }
    },
    [ownerId, preferencesStorage],
  );

  /**
   * Mirrors `_setPushNotifications`: turning push on must be granted OS
   * permission first, otherwise the toggle stays off and the user is told
   * why. Turning it off never needs permission.
   */
  const setPushNotifications = useCallback(
    async (enabled: boolean) => {
      if (!enabled) {
        await updatePreferences({ ...preferencesRef.current, pushNotifications: false });
        return;
      }
      let granted: boolean;
      try {
        granted = await pushGateway.requestPermission();
      } catch (error) {
        reportPreferencesError(error, 'SettingsScreen.setPushNotifications');
        granted = false;
      }
      if (!granted) {
        if (isMounted.current) showSnackbar(PUSH_PERMISSION_BLOCKED_MESSAGE);
        return;
      }
      await updatePreferences({ ...preferencesRef.current, pushNotifications: true });
    },
    [pushGateway, showSnackbar, updatePreferences],
  );

  const closeSheet = useCallback(() => setActiveSheet(null), []);

  /** Mirrors `_applyProfileEditResult`. */
  const applyProfileEditResult = useCallback(
    (result: ProfileEditResult) => {
      if (!isMounted.current || !result.isSuccess) return;
      if (result.profile != null) setProfile(result.profile);
      showSnackbar(PROFILE_UPDATED_MESSAGE);
    },
    [showSnackbar],
  );

  const handleProfileSheetSaved = useCallback(
    (result: ProfileEditResult) => {
      setActiveSheet(null);
      applyProfileEditResult(result);
    },
    [applyProfileEditResult],
  );

  /** Mirrors `_editEmail`: nothing to merge yet -- the change applies only once the emailed link is confirmed. */
  const handleEmailSheetSaved = useCallback(() => {
    setActiveSheet(null);
    showSnackbar(EMAIL_CHANGE_REQUESTED_MESSAGE);
  }, [showSnackbar]);

  /** Mirrors the post-picker half of `_editDob`. */
  const handleDobPicked = useCallback(
    async (picked: Date) => {
      const result = await controller.updateDob(picked);
      if (!isMounted.current) return;
      if (result.isSuccess) {
        applyProfileEditResult(result);
        return;
      }
      showSnackbar(result.errors[0] ?? controller.submissionError ?? SAVE_FAILURE_MESSAGE);
    },
    [applyProfileEditResult, controller, showSnackbar],
  );

  /** Mirrors `_logout`. */
  const handleLogout = useCallback(async () => {
    try {
      await auth.signOut();
      if (isMounted.current) router.replace(AppRoutes.login);
    } catch (error) {
      if (!isMounted.current) return;
      showSnackbar(`Could not log out: ${describeAuthError(error, 'Logout')}`);
    }
  }, [auth, showSnackbar]);

  /** The post-confirmation half of `_confirmDeleteAccount`. */
  const deleteAccount = useCallback(async () => {
    try {
      await repository.deleteAccount();
      // The server already revoked every session, so a failing sign-out call
      // must not be reported as a failed deletion; supabase-js still clears
      // the local session (and so fires SIGNED_OUT) when the server rejects it.
      try {
        await auth.signOut();
      } catch {
        // Intentionally ignored, as in the Dart screen.
      }
      if (isMounted.current) router.replace(AppRoutes.login);
    } catch (error) {
      if (!isMounted.current) return;
      showSnackbar(`Could not delete account: ${describeAuthError(error, 'Account deletion')}`);
    }
  }, [auth, repository, showSnackbar]);

  /** Mirrors the confirmation-dialog half of `_confirmDeleteAccount`: Cancel does nothing. */
  const confirmDeleteAccount = useCallback(() => {
    Alert.alert(DELETE_ACCOUNT_TITLE, DELETE_ACCOUNT_MESSAGE, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete Account', style: 'destructive', onPress: () => void deleteAccount() },
    ]);
  }, [deleteAccount]);

  const now = new Date();

  return (
    <AppScaffold title="Settings" showBackButton>
      <View className="relative flex-1">
        <ScrollView contentContainerStyle={{ padding: spacing.x5 }}>
          <NotificationsSection
            preferences={preferences}
            onPushNotificationsChange={(value) => void setPushNotifications(value)}
            onEmailNotificationsChange={(value) =>
              void updatePreferences({ ...preferencesRef.current, emailNotifications: value })
            }
            onPromotionalEmailsChange={(value) =>
              void updatePreferences({ ...preferencesRef.current, promotionalEmails: value })
            }
            onOrderUpdatesChange={(value) => void updatePreferences({ ...preferencesRef.current, orderUpdates: value })}
          />
          <View style={{ height: spacing.sectionGap }} />
          <AccountSection
            nameSubtitle={profileLoading ? LOADING : nameSubtitle(profile)}
            phoneSubtitle={profileLoading ? LOADING : profile != null && profile.phone !== '' ? profile.phone : NOT_ADDED_YET}
            dobSubtitle={profileLoading ? LOADING : profile?.dob != null ? formatShortDate(profile.dob) : NOT_ADDED_YET}
            emailSubtitle={email != null && email !== '' ? email : 'Not available'}
            onEditName={() => setActiveSheet('name')}
            onEditPhone={() => setActiveSheet('phone')}
            onEditDob={() => setIsDobPickerVisible(true)}
            onEditEmail={() => setActiveSheet('email')}
          />
          <View style={{ height: spacing.sectionGap }} />
          <PreferencesSection />
          <View style={{ height: spacing.sectionGap }} />
          <SupportSection onAboutUsPress={() => setActiveSheet('about')} />
          <View style={{ height: spacing.sectionGap }} />
          <AccountDangerZone
            onLogoutPress={() => void handleLogout()}
            onDeleteAccountPress={confirmDeleteAccount}
          />
          <View style={{ height: spacing.x6 }} />
        </ScrollView>
        <CartSnackbar message={snackbarMessage} />
      </View>

      {isDobPickerVisible && (
        <DateTimePicker
          value={profile?.dob ?? eighteenYearsAgo(now)}
          mode="date"
          display="default"
          minimumDate={new Date(now.getFullYear() - 120, now.getMonth(), now.getDate())}
          maximumDate={now}
          // A 'dismissed' event (no `selectedDate`) is a no-op, like
          // `showDatePicker` returning null on cancel.
          onChange={(_event: DateTimePickerEvent, selectedDate?: Date) => {
            setIsDobPickerVisible(false);
            if (selectedDate) void handleDobPicked(selectedDate);
          }}
        />
      )}

      <SettingsSheet visible={activeSheet !== null} onDismiss={closeSheet}>
        {activeSheet === 'name' && (
          <NameEditSheet profile={profile} controller={controller} onSaved={handleProfileSheetSaved} />
        )}
        {activeSheet === 'phone' && (
          <PhoneEditSheet profile={profile} controller={controller} onSaved={handleProfileSheetSaved} />
        )}
        {activeSheet === 'email' && (
          <EmailEditSheet email={email} controller={controller} onSaved={handleEmailSheetSaved} />
        )}
        {activeSheet === 'about' && <AboutZivoSheet />}
      </SettingsSheet>
    </AppScaffold>
  );
}
