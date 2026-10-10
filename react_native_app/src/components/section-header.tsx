import { Pressable, Text, View } from 'react-native';

export type SectionHeaderProps =
  | { title: string; actionLabel?: undefined; onPress?: undefined }
  | { title: string; actionLabel: string; onPress: () => void };

/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/section_header.dart`'s
 * `SectionHeader`: a section title with an optional trailing action link
 * (e.g. "See All"/"View All") -- both-or-neither, enforced at the type level
 * in place of the Dart `assert`.
 *
 * Distinct from `@/features/home/section-header.tsx`, a same-named but
 * separately-specified Dart widget
 * (`features/super_app/presentation/widgets/section_header.dart`) that
 * requires the action and bakes in its own vertical padding. This one adds
 * no padding of its own -- the food home screen controls the gap around
 * each call site itself, matching the Dart source here.
 */
export function SectionHeader({ title, actionLabel, onPress }: SectionHeaderProps) {
  return (
    <View className="flex-row items-center justify-between">
      <Text className="flex-1 text-sectionTitle font-outfitSemiBold text-text" numberOfLines={1}>
        {title}
      </Text>
      {actionLabel != null && (
        <Pressable
          accessibilityRole="button"
          onPress={onPress}
          style={{ minHeight: 44, minWidth: 44 }}
          className="items-center justify-center active:opacity-70">
          <Text className="text-link text-primary">{actionLabel}</Text>
        </Pressable>
      )}
    </View>
  );
}
