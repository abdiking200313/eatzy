/**
 * Ports `flutter_app/lib/widgets/error_fallback.dart` (issue #40) to this
 * app (issue #351): a minimal, on-brand replacement for React Native's
 * default red-box/LogBox screen, rendered by `ErrorBoundary`
 * (`@/platform/error-reporting/error-boundary.tsx`) in place of whatever
 * subtree failed to render. It deliberately offers no restart/retry action
 * since it has no way to know what would fix the underlying error, only
 * that something did.
 *
 * NOTE: this file is owned by the rn-logic-agent, not the rn-ui-agent who
 * normally owns `src/components/**` -- it is a one-off exception for issue
 * #351 because it is a small, purely presentational piece tightly coupled
 * to the error-boundary wiring that issue otherwise ports.
 *
 * Reads `colors.light` directly from `@/theme/tokens` instead of
 * `useSemanticColors()`/NativeWind className styling: a render error can
 * happen anywhere in the tree, including inside whatever provides those
 * reactive tokens, so this must not assume the app's own theming still
 * works. `colors.light` is the same fixed palette Flutter's fallback uses
 * (`TwColors.bg` / `TwColors.textMuted` / `TwColors.text` in
 * `flutter_app/lib/config/tailwind.dart` have no dark-mode variant either),
 * so this intentionally does not switch with the device color scheme.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { StyleSheet, Text, View } from 'react-native';

import { colors, spacing, typography } from '@/theme/tokens';

export function ErrorFallbackView() {
  return (
    <View style={[styles.container, { backgroundColor: colors.light.bg }]}>
      <View style={styles.content}>
        <MaterialIcons name="error-outline" size={40} color={colors.light.textMuted} />
        <Text style={[typography.fontBoldBase, styles.message, { color: colors.light.text }]}>
          Something went wrong
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  content: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.x6,
    paddingVertical: spacing.x6,
    gap: spacing.x3,
  },
  message: {
    textAlign: 'center',
  },
});
