/**
 * Ports `flutter_app/lib/features/settings/presentation/settings_screen.dart`
 * (issue #400 / P8-04): the Account section (Name / Phone Number / Date of
 * Birth / Email Address / Change Password, edited through
 * {@link ProfileEditController} and saved via `update_own_profile`), the
 * Preferences "Coming soon" rows, and the Support section (About sheet,
 * Privacy Policy, Terms & Conditions).
 *
 * Deliberately not here yet, each owned by its own migration issue: the
 * Notifications section (#401 / P8-05) and the Logout / Delete Account
 * danger zone (#402 / P8-06). The Profile tab already carries Logout.
 *
 * Flutter's `ScaffoldMessenger` snack bars become this screen's own
 * `CartSnackbar` + `useCartSnackbar` pair (the app's only snackbar host so
 * far); `showModalBottomSheet` becomes {@link SettingsSheet}.
 */
import DateTimePicker, { type DateTimePickerEvent } from '@react-native-community/datetimepicker';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ScrollView, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { CartSnackbar } from '@/components/cart-snackbar';
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
import { formatShortDate } from '@/platform/localization/date-format';
import { useSessionStore } from '@/stores/session-store';
import { spacing } from '@/theme/tokens';

import { AboutZivoSheet } from './about-zivo-sheet';
import { EmailEditSheet, NameEditSheet, PhoneEditSheet } from './profile-edit-sheets';
import { AccountSection, PreferencesSection, SupportSection } from './settings-sections';
import { SettingsSheet } from './settings-sheet';

export const PROFILE_UPDATED_MESSAGE = 'Profile updated';
export const EMAIL_CHANGE_REQUESTED_MESSAGE = 'Check your new inbox to confirm your email change.';
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

export type SettingsScreenProps = {
  /** Defaults to a {@link SupabaseProfileRepository} on the shared client. */
  profileRepository?: ProfileRepository;
  /** Defaults to the session store + app-wide `authService`. */
  emailAuth?: ProfileEmailAuth;
};

type ActiveSheet = 'name' | 'phone' | 'email' | 'about' | null;

/** Mirrors `_nameSubtitle`: checks first/last name directly so the "Zivo customer" display fallback never reads as a saved name. */
function nameSubtitle(profile: CustomerProfile | null): string {
  const hasName = profile != null && (profile.firstName !== '' || profile.lastName !== '');
  return hasName ? customerDisplayName(profile) : NOT_ADDED_YET;
}

function eighteenYearsAgo(now: Date): Date {
  return new Date(now.getFullYear() - 18, now.getMonth(), now.getDate());
}

export function SettingsScreen({ profileRepository, emailAuth = defaultEmailAuth }: SettingsScreenProps = {}) {
  // Resolved once, like the Dart `didChangeDependencies` guard.
  const [repository] = useState<ProfileRepository>(() => profileRepository ?? new SupabaseProfileRepository());
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

  const now = new Date();

  return (
    <AppScaffold title="Settings" showBackButton>
      <View className="relative flex-1">
        <ScrollView contentContainerStyle={{ padding: spacing.x5 }}>
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
