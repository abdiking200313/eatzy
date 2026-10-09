import { ActivityIndicator, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

export type LoadingStateProps = {
  /**
   * Optional caption under the spinner (e.g. "Loading menu…"). Most call
   * sites in flutter_app just show the bare spinner (`activity_screen.dart`,
   * `orders_screen.dart`, `my_store_screen.dart`'s `_LoadingView`, etc.) —
   * the caption matches the rarer pattern seen in
   * `restaurant_status_views.dart`'s `RestaurantLoadingView`.
   */
  message?: string;
};

/**
 * Generic "first load in flight" view: a centered spinner, with an optional
 * caption. Not a port of one specific Flutter widget — it standardizes the
 * `Center(child: CircularProgressIndicator())` shape that recurs across
 * every screen driven by `loadable_state_mixin.dart`'s
 * `LoadableState.isLoading` (issue #357).
 */
export function LoadingState({ message }: LoadingStateProps) {
  const colors = useSemanticColors();

  return (
    <View className="flex-1 items-center justify-center p-x8" testID="loading-state">
      <ActivityIndicator size="large" color={colors.primary} />
      {message && (
        <Text className="mt-x4 text-center text-textSm font-outfitRegular text-textMuted">
          {message}
        </Text>
      )}
    </View>
  );
}
