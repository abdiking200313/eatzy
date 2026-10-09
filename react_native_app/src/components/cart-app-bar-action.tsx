import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { useServiceTheme } from '@/hooks/use-service-theme';
import { spacing } from '@/theme/tokens';
import type { ServiceId } from '@/theme/service-theme';

export type CartAppBarActionProps = {
  itemCount: number;
  onPress: () => void;
  tooltip: string;
  icon?: keyof typeof MaterialIcons.glyphMap;
  /**
   * Which service's accent palette to badge this in, mirroring the
   * Flutter widget reading the ambient `ZivoServiceTheme` via
   * `context.serviceColors`. There is no such ambient theme in this app
   * yet (see src/hooks/use-service-theme.ts), so the caller passes its own
   * `ServiceId` explicitly; omit for the neutral platform palette.
   */
  service?: ServiceId;
  /** See `useServiceTheme`'s `slug` param (e.g. Fresh Meat, Electronics). */
  slug?: string;
};

// Flutter's `SizedBox.square(dimension: _dimension)` with `_dimension = 44`
// — a literal pixel size, not a `TwSpacing` token on the Dart side either.
const DIMENSION = 44;

/**
 * Ports flutter_app/lib/widgets/cart_app_bar_action.dart's
 * `CartAppBarAction`: the standard cart entry point for every service
 * vertical — a filled, service-accent-soft icon chip plus an accent-colored
 * count badge, hidden (but the chip itself always visible) when the count
 * is zero.
 *
 * `CartBadgeAction` (the same Flutter file's `AnimatedBuilder` wrapper that
 * reads `itemCount`/rebuilds off a cart controller `Listenable`) is not
 * ported here — it needs live cart-store state (GroceryController/
 * PharmacyController's RN equivalent), which is rn-logic-agent's territory.
 * That wrapper should render this component, reading `itemCount` off the
 * real cart store/hook and calling `router.push(route)` on press.
 */
export function CartAppBarAction({
  itemCount,
  onPress,
  tooltip,
  icon = 'shopping-cart',
  service = 'unknown',
  slug,
}: CartAppBarActionProps) {
  const palette = useServiceTheme(service, slug);
  const showBadge = itemCount > 0;

  return (
    <View style={{ paddingHorizontal: spacing.x2 }}>
      <View style={{ width: DIMENSION, height: DIMENSION }}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={tooltip}
          onPress={onPress}
          style={{ backgroundColor: palette.soft }}
          className="h-full w-full items-center justify-center rounded-control active:opacity-80">
          <MaterialIcons name={icon} size={24} color={palette.accent} />
        </Pressable>
        {showBadge && (
          <View
            style={{ backgroundColor: palette.accent, top: -spacing.x1, right: -spacing.x1 }}
            className="absolute min-w-x4 items-center justify-center rounded-full px-x1">
            {/* `textXs` is the closest named type-scale token to Material's
                default `Badge` label style — the Flutter widget passes no
                explicit `TwText` style to its `Badge`, so there is no exact
                1:1 token to match here either. */}
            <Text
              style={{ color: palette.onAccent }}
              className="text-textXs font-outfitSemiBold"
              numberOfLines={1}>
              {itemCount}
            </Text>
          </View>
        )}
      </View>
    </View>
  );
}
