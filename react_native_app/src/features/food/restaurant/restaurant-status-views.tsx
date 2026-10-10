/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/restaurant_status_views.dart`
 * (issue #383): the restaurant screen's first-load spinner, its
 * failed-load card, and the in-list "no menu items" view.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { LoadingState } from '@/components/loading-state';
import { OutlinedCard } from '@/components/outlined-card';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { radius, spacing } from '@/theme/tokens';

/** Shown while the menu's first load is in flight and nothing has been cached yet. */
export function RestaurantLoadingView() {
  return (
    <AppScaffold title="Restaurant" showBackButton>
      <LoadingState message="Loading menu…" />
    </AppScaffold>
  );
}

/** Shown when the menu failed to load and nothing was cached to fall back to. */
export function RestaurantErrorView({ onRetry }: { onRetry: () => void }) {
  const palette = useServiceTheme('food');
  return (
    <AppScaffold title="Restaurant" showBackButton>
      <View testID="restaurant-error" className="flex-1 items-center justify-center" style={{ padding: spacing.x5 }}>
        <View style={{ maxWidth: 420, width: '100%' }}>
          <OutlinedCard borderRadius={radius.xl}>
            <View className="items-center">
              <MaterialIcons name="cloud-off" size={42} color={palette.accent} />
              <Text style={{ marginTop: spacing.x3 }} className="text-center text-textXl font-outfitBold text-text">
                We could not load this menu
              </Text>
              <Text style={{ marginTop: spacing.x2 }} className="text-center text-textSm font-outfitRegular text-textMuted">
                Check your connection and try again.
              </Text>
              <Pressable
                accessibilityRole="button"
                onPress={onRetry}
                style={{ marginTop: spacing.x5 }}
                className="rounded-lg px-x4 py-x2 active:opacity-70">
                <Text className="text-button font-outfitSemiBold text-primary">Try again</Text>
              </Pressable>
            </View>
          </OutlinedCard>
        </View>
      </View>
    </AppScaffold>
  );
}

/** Shown in the menu list when a loaded menu has no categories. */
export function EmptyMenuView() {
  const palette = useServiceTheme('food');
  return (
    <View testID="empty-menu" className="items-center justify-center" style={{ padding: spacing.x8 }}>
      <MaterialIcons name="menu-book" size={48} color={palette.accent} />
      <Text style={{ marginTop: spacing.x3 }} className="text-center text-textXl font-outfitBold text-text">
        No menu items yet
      </Text>
      <Text style={{ marginTop: spacing.x2 }} className="text-center text-textSm font-outfitRegular text-textMuted">
        This restaurant has not added any items.
      </Text>
    </View>
  );
}
