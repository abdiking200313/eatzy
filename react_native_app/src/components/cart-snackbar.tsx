import { Text, View } from 'react-native';

import { rawColors, radius, spacing } from '@/theme/tokens';

export type CartSnackbarProps = {
  message: string | null;
};

/**
 * Ports flutter_app/lib/widgets/app_misc.dart's `showCartSnackBar`'s visual
 * shape: a floating, dark pill anchored to the bottom of the screen. Pair
 * with `useCartSnackbar` (src/hooks/use-cart-snackbar.ts) for the
 * show/auto-hide behavior — see that hook's doc comment for how this
 * differs from the Flutter original's app-wide `ScaffoldMessenger`.
 *
 * Render this inside a `relative`-positioned container that fills the
 * screen (or at least its bottom-safe area) so the `absolute` positioning
 * below anchors correctly.
 */
export function CartSnackbar({ message }: CartSnackbarProps) {
  if (!message) {
    return null;
  }

  return (
    <View
      pointerEvents="none"
      style={{ left: spacing.x4, right: spacing.x4, bottom: spacing.x4 }}
      className="absolute items-center">
      <View
        style={{ backgroundColor: rawColors.slate900, borderRadius: radius.md, paddingHorizontal: spacing.x4, paddingVertical: spacing.x3 }}
        className="shadow-card">
        <Text style={{ color: rawColors.white }} className="text-textSm font-outfitRegular" numberOfLines={2}>
          {message}
        </Text>
      </View>
    </View>
  );
}
