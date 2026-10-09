import type { ReactNode } from 'react';
import { View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, rawColors, shadows, spacing } from '@/theme/tokens';

export type AuthCardProps = {
  children: ReactNode;
};

/**
 * Ports flutter_app/lib/widgets/app_widgets.dart's `AuthCard`: the bordered,
 * white, shadowed panel wrapping the login/signup form.
 *
 * `backgroundColor` uses the raw, fixed `white` token directly, matching
 * the Flutter widget's own hardcoded `TwColors.white` (the raw palette is
 * "identical in light & dark" by design — see theme/tokens.ts's
 * `rawColors` doc comment). `borderColor` uses the *semantic* `border`
 * token (`TwColors.border` on the Dart side), which does flip with dark
 * mode here, same as every other semantic alias in this port.
 */
export function AuthCard({ children }: AuthCardProps) {
  const colors = useSemanticColors();

  return (
    <View
      style={[
        shadows.panel,
        {
          backgroundColor: rawColors.white,
          borderRadius: radius.xl,
          borderWidth: 1,
          borderColor: colors.border,
          padding: spacing.x6,
        },
      ]}
      className="w-full">
      {children}
    </View>
  );
}
