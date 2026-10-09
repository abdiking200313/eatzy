import { MaterialIcons } from '@expo/vector-icons';
import { Pressable } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

export type AddToCartButtonProps = {
  tooltip: string;
  onPress?: (() => void) | null;
};

// Flutter's `SizedBox.square(dimension: 44)` — a literal pixel size the
// Dart widget itself never ties to a `TwSpacing` token, so it's kept as a
// literal constant here too rather than snapping to the nearest token.
const DIMENSION = 44;

/**
 * Ports flutter_app/lib/widgets/add_to_cart_button.dart's
 * `AddToCartButton`: a filled, 44x44 icon button with one trailing cart
 * glyph, used across food/grocery/pharmacy product rows. Disabled (no
 * `onPress`) swaps to the neutral `border`/`textMuted` tokens, matching
 * `IconButton.styleFrom`'s `disabledBackgroundColor`/`disabledForegroundColor`.
 *
 * `tooltip` doubles as the accessibility label — React Native has no native
 * hover tooltip, so `accessibilityLabel` is the closest match to Flutter's
 * `Tooltip`-wrapped `IconButton`.
 */
export function AddToCartButton({ tooltip, onPress }: AddToCartButtonProps) {
  const disabled = !onPress;
  const colors = useSemanticColors();

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={tooltip}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress ?? undefined}
      style={{ width: DIMENSION, height: DIMENSION }}
      className={`items-center justify-center rounded-control ${
        disabled ? 'bg-border' : 'bg-primary active:opacity-80'
      }`}>
      <MaterialIcons
        name="add-shopping-cart"
        size={20}
        color={disabled ? colors.textMuted : colors.onPrimary}
      />
    </Pressable>
  );
}
