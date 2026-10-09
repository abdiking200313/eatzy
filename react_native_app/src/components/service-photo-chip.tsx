import { View } from 'react-native';

import { NetworkAvatar } from '@/components/network-avatar';
import { SERVICE_ICON_CHIP_DEFAULT_SIZE } from '@/components/service-icon-chip';
import { useServiceTheme } from '@/hooks/use-service-theme';
import type { ServiceId } from '@/theme/service-theme';

export type ServicePhotoChipProps = {
  imageUrl: string;
  ringColor?: string;
  size?: number;
  /** See `ServiceIconChip`'s `service` prop. */
  service?: ServiceId;
  /** See `useServiceTheme`'s `slug` param (e.g. Fresh Meat, Electronics). */
  slug?: string;
};

const RING_WIDTH = 2;

/**
 * Ports flutter_app/lib/widgets/app_misc.dart's `ServicePhotoChip`: the
 * photo counterpart of `ServiceIconChip` — the same 48x48 circular slot, a
 * cropped photo instead of an icon, ringed in the per-service accent so it
 * reads as the same category-chip language.
 */
export function ServicePhotoChip({
  imageUrl,
  ringColor,
  size = SERVICE_ICON_CHIP_DEFAULT_SIZE,
  service = 'unknown',
  slug,
}: ServicePhotoChipProps) {
  const palette = useServiceTheme(service, slug);

  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        borderWidth: RING_WIDTH,
        borderColor: ringColor ?? palette.accent,
        padding: RING_WIDTH,
      }}>
      <NetworkAvatar imageUrl={imageUrl} radius={(size - RING_WIDTH * 4) / 2} />
    </View>
  );
}
