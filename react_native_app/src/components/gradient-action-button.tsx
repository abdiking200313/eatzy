import type { ReactNode } from 'react';
import { Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { shadows, spacing } from '@/theme/tokens';

export type GradientActionButtonProps = {
  label: string;
  onPress?: (() => void) | null;
  icon?: ReactNode;
  fullWidth?: boolean;
  /** Vertical/horizontal padding, matching Flutter's single `padding` prop. */
  paddingVertical?: number;
  paddingHorizontal?: number;
  borderRadius?: number;
  fontSize?: number;
  /**
   * Mirrors a Flutter `Key` on the widget itself (e.g. `cart_view.dart`'s
   * `Key('cart-checkout')`, `checkout_view.dart`'s
   * `Key('checkout-place-order')`) so a test can find this exact button.
   */
  testID?: string;
};

/**
 * Ports flutter_app/lib/widgets/app_cards.dart's `GradientActionButton`: a
 * large, pill-shaped primary CTA (e.g. "Get Started", "Checkout") with an
 * optional trailing icon. Despite the name, the Flutter widget itself fills
 * with a solid `scheme.primary`, not an actual gradient — this is a 1:1
 * port of that, not a simplification.
 */
export function GradientActionButton({
  label,
  onPress,
  icon,
  fullWidth = true,
  paddingVertical = spacing.x5,
  paddingHorizontal = spacing.x5,
  borderRadius = 50,
  fontSize,
  testID,
}: GradientActionButtonProps) {
  const colors = useSemanticColors();
  const disabled = !onPress;

  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress ?? undefined}
      style={{ opacity: disabled ? 0.55 : 1 }}
      className={fullWidth ? 'w-full' : 'self-start'}>
      <View
        style={[
          shadows.button,
          {
            backgroundColor: colors.primary,
            borderRadius,
            paddingVertical,
            paddingHorizontal,
          },
        ]}
        className="flex-row items-center justify-center">
        <Text
          style={{ color: colors.onPrimary, fontSize }}
          className="shrink text-button font-outfitSemiBold"
          numberOfLines={1}>
          {label}
        </Text>
        {icon && <View style={{ marginLeft: spacing.x2 }}>{icon}</View>}
      </View>
    </Pressable>
  );
}
