import type { ReactNode } from 'react';
import { Pressable, View, type AccessibilityActionEvent, type AccessibilityActionInfo } from 'react-native';

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
  /** Overrides the name a screen reader announces for a pressable card
   * (defaults to the concatenated text of its children). */
  accessibilityLabel?: string;
  /** What activating a pressable card does, e.g. "Opens item details". */
  accessibilityHint?: string;
  /**
   * Custom screen-reader actions for a pressable card. A pressable card is
   * one focusable element on iOS, so a nested button (e.g. a row's
   * add-to-cart button) is not separately reachable by VoiceOver — expose
   * it here as a named action instead (issue #416).
   */
  accessibilityActions?: readonly AccessibilityActionInfo[];
  onAccessibilityAction?: (event: AccessibilityActionEvent) => void;
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
  accessibilityLabel,
  accessibilityHint,
  accessibilityActions,
  onAccessibilityAction,
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
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint}
      accessibilityActions={accessibilityActions}
      onAccessibilityAction={onAccessibilityAction}
      onPress={onPress}
      style={style}
      className="active:opacity-80">
      {children}
    </Pressable>
  );
}
