import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { rawColors, spacing } from '@/theme/tokens';

export type StatusPillProps = {
  label: string;
  backgroundColor?: string;
  foregroundColor?: string;
  /** Matches the Dart default of `12` — not a `TwText` size on that side
   * either (the Flutter widget hardcodes it, independent of the `TwText`
   * scale). */
  fontSize?: number;
  icon?: keyof typeof MaterialIcons.glyphMap;
};

/**
 * Ports flutter_app/lib/widgets/app_misc.dart's `StatusPill`: a small
 * pill-shaped status indicator (e.g. "On the way", "Delivered").
 */
export function StatusPill({ label, backgroundColor, foregroundColor, fontSize = 12, icon }: StatusPillProps) {
  const colors = useSemanticColors();
  const bg = backgroundColor ?? colors.primaryAccent;
  const fg = foregroundColor ?? rawColors.blue900;

  return (
    <View
      style={{ backgroundColor: bg, paddingHorizontal: spacing.x3, paddingVertical: spacing.x1 }}
      className="flex-row items-center self-start rounded-full">
      {icon && <MaterialIcons name={icon} size={fontSize + 2} color={fg} style={{ marginRight: spacing.x1 }} />}
      <Text style={{ color: fg, fontSize }} className="shrink font-outfitMedium" numberOfLines={1}>
        {label}
      </Text>
    </View>
  );
}
