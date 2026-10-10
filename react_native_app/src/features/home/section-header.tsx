import { Pressable, Text, View } from 'react-native';

import { spacing } from '@/theme/tokens';

export type SectionHeaderProps = {
  title: string;
  actionLabel: string;
  onPress: () => void;
};

/**
 * Ports `flutter_app/lib/features/super_app/presentation/widgets/section_header.dart`'s
 * `SectionHeader`: a section title with a trailing action link (e.g. "See
 * all"), used by the home screen and its Recent Activity preview.
 *
 * The Dart source trims its own top/bottom padding by the action link's
 * 44px tap-target overhang past the title's measured text height, so a
 * fixed-looking gap on screen doesn't also grow by the tap target's own
 * extra height. This port uses `spacing.sectionGap`/`spacing.headerToContent`
 * directly without that overhang reduction -- a minor spacing
 * simplification (not a behavior difference the acceptance criteria call
 * out), since RN's testing-library has no real layout pass to measure
 * against the way the Dart source's own math does.
 */
export function SectionHeader({ title, actionLabel, onPress }: SectionHeaderProps) {
  return (
    <View style={{ paddingTop: spacing.sectionGap, paddingBottom: spacing.headerToContent }} className="flex-row items-center">
      <Text className="flex-1 text-sectionTitle font-outfitSemiBold text-text" numberOfLines={1}>
        {title}
      </Text>
      <Pressable accessibilityRole="button" onPress={onPress} style={{ minHeight: 44, minWidth: 44 }} className="items-center justify-center active:opacity-70">
        <Text className="text-link text-primary">{actionLabel}</Text>
      </Pressable>
    </View>
  );
}
