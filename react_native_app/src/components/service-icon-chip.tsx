import { MaterialIcons } from '@expo/vector-icons';
import { View } from 'react-native';

import { useServiceTheme } from '@/hooks/use-service-theme';
import type { ServiceId } from '@/theme/service-theme';
import { radius, spacing } from '@/theme/tokens';

export type ServiceIconChipProps = {
  icon: keyof typeof MaterialIcons.glyphMap;
  background?: string;
  foreground?: string;
  borderRadius?: number;
  iconSize?: number;
  size?: number;
  /**
   * Which service's accent palette to fall back to when `background`/
   * `foreground` are not given, mirroring the Flutter widget reading the
   * ambient `ZivoServiceTheme` via `context.serviceColors`. There is no
   * such ambient theme in this app yet (see
   * src/hooks/use-service-theme.ts), so the caller passes its own
   * `ServiceId` explicitly; omit for the neutral platform palette.
   */
  service?: ServiceId;
  /** See `useServiceTheme`'s `slug` param (e.g. Fresh Meat, Electronics). */
  slug?: string;
};

export const SERVICE_ICON_CHIP_DEFAULT_SIZE = spacing.x12;

/**
 * Ports flutter_app/lib/widgets/app_misc.dart's `ServiceIconChip`: the one
 * place a per-service accent color is allowed to appear outside a button —
 * a rounded chip (48x48 by default) holding an icon. Cards, list rows, and
 * section headers must stay on the neutral tokens and use this (or its
 * photo counterpart, `ServicePhotoChip`) instead of tinting their own
 * background/border.
 */
export function ServiceIconChip({
  icon,
  background,
  foreground,
  borderRadius = radius.lg,
  iconSize = spacing.x6,
  size = SERVICE_ICON_CHIP_DEFAULT_SIZE,
  service = 'unknown',
  slug,
}: ServiceIconChipProps) {
  const palette = useServiceTheme(service, slug);

  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius,
        backgroundColor: background ?? palette.accent,
      }}
      className="items-center justify-center">
      <MaterialIcons name={icon} size={iconSize} color={foreground ?? palette.onAccent} />
    </View>
  );
}
