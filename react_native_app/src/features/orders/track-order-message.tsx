import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

export type TrackOrderMessageProps = {
  icon: keyof typeof MaterialIcons.glyphMap;
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
};

/**
 * Ports `flutter_app/lib/features/orders/presentation/widgets/track_order_message.dart`:
 * a centered icon/title/message empty or error state for the track-order
 * screen, with an optional retry action (shown only when both
 * `actionLabel` and `onAction` are given, like the Dart widget).
 */
export function TrackOrderMessage({ icon, title, message, actionLabel, onAction }: TrackOrderMessageProps) {
  const colors = useSemanticColors();
  return (
    <View className="flex-1 items-center justify-center p-x8">
      <MaterialIcons name={icon} size={48} color={colors.textMuted} />
      <Text className="mt-x3 text-center text-fontBoldBase font-outfitSemiBold text-text">{title}</Text>
      <Text className="mt-x2 text-center text-textSm font-outfitRegular text-textMuted">{message}</Text>
      {actionLabel != null && onAction != null && (
        <Pressable accessibilityRole="button" onPress={onAction} className="mt-x4 rounded-full bg-primary px-x5 py-x3 active:opacity-80">
          <Text className="text-button font-outfitSemiBold text-onPrimary">{actionLabel}</Text>
        </Pressable>
      )}
    </View>
  );
}
