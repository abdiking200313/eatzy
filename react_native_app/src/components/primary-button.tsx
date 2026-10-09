import type { ReactNode } from 'react';
import { Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { rawColors, spacing } from '@/theme/tokens';

export type PrimaryButtonProps = {
  label: string;
  onPress: () => void;
  icon?: ReactNode;
  color?: string;
  foregroundColor?: string;
  fullWidth?: boolean;
};

/**
 * Ports flutter_app/lib/widgets/app_cards.dart's `PrimaryButton`: a
 * rounded, solid-color button for less prominent actions than
 * `GradientActionButton`.
 */
export function PrimaryButton({
  label,
  onPress,
  icon,
  color,
  // Dart default is `Colors.white` — the raw, fixed `white` token (not the
  // semantic `onPrimary` alias), only used when `color` is also overridden.
  foregroundColor = rawColors.white,
  fullWidth = true,
}: PrimaryButtonProps) {
  const colors = useSemanticColors();
  const resolvedColor = color ?? colors.primary;
  // Matches the Dart ternary: an explicit `foregroundColor` only applies
  // when `color` is also overridden — otherwise the resolved foreground
  // always follows the theme's `onPrimary`.
  const resolvedForeground = color == null ? colors.onPrimary : foregroundColor;

  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={{ backgroundColor: resolvedColor, paddingVertical: spacing.x5 }}
      className={`flex-row items-center justify-center rounded-xl active:opacity-80 ${
        fullWidth ? 'w-full' : 'self-start'
      }`}>
      <Text style={{ color: resolvedForeground }} className="text-button font-outfitSemiBold">
        {label}
      </Text>
      {icon && <View style={{ marginLeft: spacing.x2 }}>{icon}</View>}
    </Pressable>
  );
}
