import { Switch, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

export type ToggleCardProps = {
  title: string;
  subtitle: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
};

/**
 * Ports `flutter_app/lib/features/settings/presentation/widgets/toggle_card.dart`
 * (issue #400 / P8-04): a single, bare toggle row. Nothing renders it yet --
 * its only Flutter caller is the Notifications section, which lands with
 * #401 (P8-05).
 */
export function ToggleCard({ title, subtitle, value, onValueChange }: ToggleCardProps) {
  const colors = useSemanticColors();
  return (
    <View
      style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3_5 }}
      className="flex-row items-center">
      <View className="flex-1">
        <Text className="text-fontBoldSm font-outfitSemiBold text-text">{title}</Text>
        <Text style={{ marginTop: 3 }} className="text-textXs font-outfitMedium text-textMuted">
          {subtitle}
        </Text>
      </View>
      <View style={{ width: spacing.x4 }} />
      <Switch
        accessibilityLabel={title}
        value={value}
        onValueChange={onValueChange}
        thumbColor={value ? colors.primary : undefined}
        trackColor={{ false: colors.textMuted, true: colors.primarySoft }}
        style={{ transform: [{ scale: 0.8 }] }}
      />
    </View>
  );
}
