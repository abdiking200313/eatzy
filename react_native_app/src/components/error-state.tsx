import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

export type ErrorStateProps = {
  /** Shown below the icon — typically the `loadError` string from `loadable_state_mixin.dart`'s `LoadableState`. */
  message: string;
  /** Re-runs the failed load, e.g. `LoadableState.runLoad`'s `fetch` again. */
  onRetry: () => void;
  /** Matches the Dart `FilledButton`'s default label across every call site (`activity_screen.dart`, `orders_screen.dart`, `my_store_screen.dart`, etc). */
  retryLabel?: string;
};

/**
 * Generic "the load failed" view: an error icon, the error message, and a
 * retry button. Not a port of one specific Flutter widget — it standardizes
 * the `Icon(Icons.error_outline_rounded) + Text(message) +
 * FilledButton(onPressed: onRetry, child: Text('Try again'))` column that
 * recurs identically across every screen driven by
 * `loadable_state_mixin.dart`'s `LoadableState.loadError` (issue #357).
 */
export function ErrorState({ message, onRetry, retryLabel = 'Try again' }: ErrorStateProps) {
  const colors = useSemanticColors();

  return (
    <View className="flex-1 items-center justify-center p-x8" testID="error-state">
      <MaterialIcons name="error-outline" size={48} color={colors.error} />
      <Text className="mt-x4 text-center text-textSm font-outfitRegular text-text">{message}</Text>
      <Pressable
        accessibilityRole="button"
        onPress={onRetry}
        className="mt-x4 rounded-lg bg-primary px-x5 py-x3 active:opacity-80">
        <Text className="text-button font-outfitSemiBold text-onPrimary">{retryLabel}</Text>
      </Pressable>
    </View>
  );
}
