/**
 * Ports the Settings screen's static-shape sections from
 * `flutter_app/lib/features/settings/presentation/widgets/`
 * (`account_section.dart`, `preferences_section.dart`,
 * `support_section.dart`; issue #400 / P8-04 -- and
 * `notifications_section.dart`; issue #401 / P8-05). Each is a plain presenter:
 * the screen resolves every subtitle and owns every tap handler.
 */
import { router } from 'expo-router';
import { View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { SectionTitle } from '@/components/section-title';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { radius, spacing } from '@/theme/tokens';

import type { NotificationPreferences } from './api/notification-preferences-repository';
import { SettingCard, SettingDivider } from './setting-card';
import { ToggleCard } from './toggle-card';

function SettingsSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View>
      <SectionTitle title={title} />
      <View style={{ height: spacing.headerToContent }} />
      <OutlinedCard padding={0} borderRadius={radius.card}>
        {children}
      </OutlinedCard>
    </View>
  );
}

export type NotificationsSectionProps = {
  preferences: NotificationPreferences;
  onPushNotificationsChange: (value: boolean) => void;
  onEmailNotificationsChange: (value: boolean) => void;
  onPromotionalEmailsChange: (value: boolean) => void;
  onOrderUpdatesChange: (value: boolean) => void;
};

/**
 * Push / Email / Promotional / Order-updates toggles. Persistence and the
 * push-permission flow stay with the screen, like Flutter's.
 */
export function NotificationsSection({
  preferences,
  onPushNotificationsChange,
  onEmailNotificationsChange,
  onPromotionalEmailsChange,
  onOrderUpdatesChange,
}: NotificationsSectionProps) {
  return (
    <SettingsSection title="Notifications">
      <ToggleCard
        title="Push Notifications"
        subtitle="Get notifications about your orders"
        value={preferences.pushNotifications}
        onValueChange={onPushNotificationsChange}
      />
      <SettingDivider />
      <ToggleCard
        title="Email Notifications"
        subtitle="Receive updates via email"
        value={preferences.emailNotifications}
        onValueChange={onEmailNotificationsChange}
      />
      <SettingDivider />
      <ToggleCard
        title="Promotional Emails"
        subtitle="Get exclusive deals and offers"
        value={preferences.promotionalEmails}
        onValueChange={onPromotionalEmailsChange}
      />
      <SettingDivider />
      <ToggleCard
        title="Order Updates"
        subtitle="Receive order status updates"
        value={preferences.orderUpdates}
        onValueChange={onOrderUpdatesChange}
      />
    </SettingsSection>
  );
}

export type AccountSectionProps = {
  nameSubtitle: string;
  phoneSubtitle: string;
  dobSubtitle: string;
  emailSubtitle: string;
  onEditName: () => void;
  onEditPhone: () => void;
  onEditDob: () => void;
  onEditEmail: () => void;
};

/** Name / Phone Number / Date of Birth / Email Address / Change Password. */
export function AccountSection({
  nameSubtitle,
  phoneSubtitle,
  dobSubtitle,
  emailSubtitle,
  onEditName,
  onEditPhone,
  onEditDob,
  onEditEmail,
}: AccountSectionProps) {
  return (
    <SettingsSection title="Account">
      <SettingCard title="Name" subtitle={nameSubtitle} icon="person-outline" onPress={onEditName} />
      <SettingDivider />
      <SettingCard title="Phone Number" subtitle={phoneSubtitle} icon="phone" onPress={onEditPhone} />
      <SettingDivider />
      <SettingCard title="Date of Birth" subtitle={dobSubtitle} icon="cake" onPress={onEditDob} />
      <SettingDivider />
      <SettingCard title="Email Address" subtitle={emailSubtitle} icon="mail-outline" onPress={onEditEmail} />
      <SettingDivider />
      <SettingCard
        title="Change Password"
        subtitle="Update your password"
        icon="lock-outline"
        onPress={() => router.push(AppRoutes.resetPassword)}
      />
    </SettingsSection>
  );
}

/**
 * Language / Currency / Theme. No language/currency/theme infrastructure
 * exists yet, so these stay non-interactive "Coming soon" rows (no chevron,
 * no tap) rather than implying settings that don't do anything.
 */
export function PreferencesSection() {
  return (
    <SettingsSection title="Preferences">
      <SettingCard title="Language" subtitle="Coming soon" icon="language" />
      <SettingDivider />
      <SettingCard title="Currency" subtitle="Coming soon" icon="attach-money" />
      <SettingDivider />
      <SettingCard title="Theme" subtitle="Coming soon" icon="brightness-7" />
    </SettingsSection>
  );
}

/** About Us / Privacy Policy / Terms & Conditions. */
export function SupportSection({ onAboutUsPress }: { onAboutUsPress: () => void }) {
  return (
    <SettingsSection title="Support">
      <SettingCard title="About Us" subtitle="Learn about Zivo" icon="info-outline" onPress={onAboutUsPress} />
      <SettingDivider />
      <SettingCard
        title="Privacy Policy"
        subtitle="How we handle your data"
        icon="privacy-tip"
        onPress={() => router.push(AppRoutes.privacyPolicy)}
      />
      <SettingDivider />
      <SettingCard
        title="Terms & Conditions"
        subtitle="Rules for using Zivo"
        icon="description"
        onPress={() => router.push(AppRoutes.termsOfService)}
      />
    </SettingsSection>
  );
}
