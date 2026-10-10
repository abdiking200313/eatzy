import { Text, View } from 'react-native';

import { spacing } from '@/theme/tokens';

/**
 * Ports `flutter_app/lib/features/settings/presentation/widgets/about_zivo_sheet.dart`
 * (issue #400 / P8-04): a minimal, static "About" surface for the About Us
 * row -- app identity plus a one-line description, same text as Flutter
 * (including its hard-coded version string).
 */
export function AboutZivoSheet() {
  return (
    <View style={{ paddingHorizontal: spacing.x5, paddingTop: spacing.x2, paddingBottom: spacing.x6 }}>
      <Text className="text-textXl font-outfitBold text-text">Zivo</Text>
      <Text style={{ marginTop: spacing.x2 }} className="text-textXs font-outfitMedium text-textMuted">
        Version 1.0.0
      </Text>
      <Text style={{ marginTop: spacing.x3_5 }} className="text-textSm font-outfitRegular text-text">
        Zivo is a modular delivery app. Food delivery is live today, with grocery and pharmacy ordering on the way.
      </Text>
    </View>
  );
}
