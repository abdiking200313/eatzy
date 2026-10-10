/**
 * Ports `flutter_app/lib/features/settings/presentation/widgets/account_danger_zone.dart`
 * (issue #402 / P8-06): the Settings screen's bottom "Logout" / "Delete
 * Account" actions.
 *
 * `onDeleteAccountPress` is expected to own the confirmation step itself
 * (as `SettingsScreen`'s `confirmDeleteAccount` does, mirroring the Dart
 * screen's `_confirmDeleteAccount`) -- this component just renders the two
 * actions.
 */
import { Pressable, Text, View } from 'react-native';

import { PrimaryButton } from '@/components/primary-button';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

export type AccountDangerZoneProps = {
  onLogoutPress: () => void;
  onDeleteAccountPress: () => void;
};

export function AccountDangerZone({ onLogoutPress, onDeleteAccountPress }: AccountDangerZoneProps) {
  const colors = useSemanticColors();
  return (
    <View>
      <PrimaryButton label="Logout" onPress={onLogoutPress} color={colors.error} />
      <View style={{ height: spacing.x3_5 }} />
      <View className="items-center">
        {/* Flutter `TextButton`: a compact, padded text-only tap target. */}
        <Pressable
          accessibilityRole="button"
          onPress={onDeleteAccountPress}
          style={{ paddingHorizontal: spacing.x3, paddingVertical: spacing.x2 }}
          className="active:opacity-70">
          <Text style={{ color: colors.error }} className="text-button font-outfitSemiBold">
            Delete Account
          </Text>
        </Pressable>
      </View>
    </View>
  );
}
