import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { rawColors, radius, spacing } from '@/theme/tokens';

/** One step in `TrackingCard`'s progress timeline. Ports `TimelineStep`. */
export interface TimelineStep {
  label: string;
  isCompleted: boolean;
  hasConnector: boolean;
}

export type TimelineStepRowProps = {
  step: TimelineStep;
  /** The route's service accent (the Dart `context.serviceColors.accent`). */
  accent: string;
};

/**
 * Ports `flutter_app/lib/features/orders/presentation/widgets/timeline_step_row.dart`:
 * a dot (filled and checked when completed), a connecting line down to the
 * next step, and the step's label.
 */
export function TimelineStepRow({ step, accent }: TimelineStepRowProps) {
  const colors = useSemanticColors();
  const lineColor = step.isCompleted ? accent : colors.borderStrong;
  return (
    <View testID="timeline-step" accessibilityState={{ checked: step.isCompleted }} className="flex-row items-start">
      <View className="items-center">
        <View
          style={{ width: spacing.x5, height: spacing.x5, borderRadius: radius.full, backgroundColor: lineColor }}
          className="items-center justify-center">
          {step.isCompleted && <MaterialIcons name="check" size={12} color={rawColors.white} />}
        </View>
        {step.hasConnector && <View style={{ width: 2, height: spacing.x6, backgroundColor: lineColor }} />}
      </View>
      <Text
        style={{ marginLeft: spacing.x4, color: step.isCompleted ? colors.text : colors.textMuted }}
        className="flex-1 text-fontBoldSm font-outfitSemiBold">
        {step.label}
      </Text>
    </View>
  );
}
