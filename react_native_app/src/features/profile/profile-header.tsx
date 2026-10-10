import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

export type ProfileHeaderProps = {
  displayName: string;
  contactLabel: string;
  isLoading?: boolean;
};

/**
 * Ports `flutter_app/lib/features/profile/presentation/widgets/profile_header.dart`'s
 * `ProfileHeader` (issue #399 / P8-03): avatar circle, display name (or a
 * loading label), and a contact line. The Profile tab is platform-level,
 * so it uses the neutral platform palette (`primary`/`primarySoft`) that
 * `context.serviceColors` resolves to outside any service vertical.
 */
export function ProfileHeader({ displayName, contactLabel, isLoading = false }: ProfileHeaderProps) {
  const colors = useSemanticColors();
  return (
    <OutlinedCard padding={spacing.x4}>
      <View className="flex-row items-center">
        <View
          style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: colors.primarySoft }}
          className="items-center justify-center">
          <MaterialIcons name="person-outline" size={32} color={colors.primary} />
        </View>
        <View style={{ marginLeft: spacing.x4 }} className="flex-1">
          <Text numberOfLines={2} className="text-textLg font-outfitSemiBold text-text">
            {isLoading ? 'Loading profile…' : displayName}
          </Text>
          <View style={{ marginTop: spacing.x1 }} className="flex-row items-center">
            <MaterialIcons name="contact-phone" size={16} color={colors.textMuted} />
            <Text numberOfLines={2} style={{ marginLeft: spacing.x2 }} className="flex-1 text-textXs text-textMuted">
              {contactLabel}
            </Text>
          </View>
        </View>
      </View>
    </OutlinedCard>
  );
}
