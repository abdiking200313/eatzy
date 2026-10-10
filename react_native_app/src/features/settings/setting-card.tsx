import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

export type SettingCardProps = {
  title: string;
  subtitle: string;
  icon: keyof typeof MaterialIcons.glyphMap;
  onPress?: () => void;
};

/**
 * Ports `flutter_app/lib/features/settings/presentation/widgets/setting_card.dart`
 * (issue #400 / P8-04): a single, bare settings row, composed several to an
 * `OutlinedCard` with internal dividers ("one card per list, not one card
 * per row").
 *
 * The trailing chevron only renders when `onPress` is set -- a row with no
 * destination must not imply navigation that does nothing.
 */
export function SettingCard({ title, subtitle, icon, onPress }: SettingCardProps) {
  const colors = useSemanticColors();
  const row = (
    <View
      style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3_5 }}
      className="flex-row items-center">
      <View style={{ width: 42, height: 42 }} className="items-center justify-center">
        <MaterialIcons name={icon} size={24} color={colors.primary} />
      </View>
      <View style={{ marginLeft: spacing.x3_5 }} className="flex-1">
        <Text className="text-fontBoldSm font-outfitSemiBold text-text">{title}</Text>
        <Text style={{ marginTop: 3 }} className="text-textXs font-outfitMedium text-textMuted">
          {subtitle}
        </Text>
      </View>
      {onPress && <MaterialIcons testID="setting-card-chevron" name="arrow-forward-ios" size={16} color={colors.textMuted} />}
    </View>
  );

  if (!onPress) return row;

  return (
    <Pressable accessibilityRole="button" accessibilityLabel={title} onPress={onPress} className="active:opacity-70">
      {row}
    </Pressable>
  );
}

/** The 1px divider between rows inside a settings card -- Dart's `Divider(height: 1)`. */
export function SettingDivider() {
  const colors = useSemanticColors();
  return <View style={{ height: 1, backgroundColor: colors.border }} />;
}
