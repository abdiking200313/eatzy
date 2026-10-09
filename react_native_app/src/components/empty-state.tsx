import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

export type EmptyStateProps = {
  /** Which Material icon represents the empty collection (e.g. `"receipt-long"` for an empty order history, `"storefront"` for no stores). Required — unlike the error icon, the Flutter source varies this per screen. */
  icon: keyof typeof MaterialIcons.glyphMap;
  title: string;
  message?: string;
};

/**
 * Generic "loaded successfully but there is nothing to show" view: a muted
 * icon, a bold title, and optional supporting copy. Not a port of one
 * specific Flutter widget — it standardizes the icon/title/subtitle column
 * that recurs across every empty list once a
 * `loadable_state_mixin.dart`-driven load succeeds with zero items (e.g.
 * `activity_screen.dart`'s `_EmptyActivity`, `orders_screen.dart`'s empty
 * view, `restaurant_status_views.dart`'s `EmptyMenuView`) (issue #357).
 */
export function EmptyState({ icon, title, message }: EmptyStateProps) {
  const colors = useSemanticColors();

  return (
    <View className="flex-1 items-center justify-center p-x8" testID="empty-state">
      <MaterialIcons name={icon} size={48} color={colors.textMuted} />
      <Text className="mt-x3 text-center text-textXl font-outfitBold text-text">{title}</Text>
      {message && (
        <Text className="mt-x2 text-center text-textSm font-outfitRegular text-textMuted">
          {message}
        </Text>
      )}
    </View>
  );
}
