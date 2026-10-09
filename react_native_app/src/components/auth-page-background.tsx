import type { ReactNode } from 'react';
import { useWindowDimensions, View } from 'react-native';

export type AuthPageBackgroundProps = {
  children: ReactNode;
};

/**
 * Ports flutter_app/lib/widgets/app_widgets.dart's `AuthPageBackground`:
 * full-bleed scaffold background behind the login/signup forms, at least
 * as tall as the screen so a short form still fills it.
 */
export function AuthPageBackground({ children }: AuthPageBackgroundProps) {
  const { height } = useWindowDimensions();

  return (
    <View className="bg-bg">
      <View style={{ minHeight: height }} className="w-full">
        {children}
      </View>
    </View>
  );
}
