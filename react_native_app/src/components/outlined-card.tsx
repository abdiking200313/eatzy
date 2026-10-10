import type { ReactNode } from 'react';
import { Pressable, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, shadows, spacing } from '@/theme/tokens';

export type OutlinedCardProps = {
  children: ReactNode;
  padding?: number;
  borderRadius?: number;
  backgroundColor?: string;
  borderColor?: string;
  borderWidth?: number;
  onPress?: () => void;
  testID?: string;
};

/**
 * Ports flutter_app/lib/widgets/app_cards.dart's `OutlinedCard`: the
 * neutral, white, bordered card used across screens ("white cards only" —
 * pass `backgroundColor`/`borderColor` explicitly for the rare intentional
 * exception, same as the Flutter doc comment).
 */
export function OutlinedCard({
  children,
  padding = spacing.x5,
  borderRadius = radius.lg,
  backgroundColor,
  borderColor,
  borderWidth = 1,
  onPress,
  testID,
}: OutlinedCardProps) {
  const colors = useSemanticColors();
  const style = [
    shadows.card,
    {
      backgroundColor: backgroundColor ?? colors.card,
      borderRadius,
      borderColor: borderColor ?? colors.border,
      borderWidth,
      padding,
      overflow: 'hidden' as const,
    },
  ];

  if (!onPress) {
    return (
      <View testID={testID} style={style}>
        {children}
      </View>
    );
  }

  return (
    <Pressable testID={testID} accessibilityRole="button" onPress={onPress} style={style} className="active:opacity-80">
      {children}
    </Pressable>
  );
}
