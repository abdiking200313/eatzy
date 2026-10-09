import { Image } from 'expo-image';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { View } from 'react-native';

import { radius } from '@/theme/tokens';

export type PhotoThumbnailProps = {
  imageUrl?: string | null;
  fallback: ReactNode;
  size?: number;
};

/**
 * Ports flutter_app/lib/widgets/app_misc.dart's `PhotoThumbnail`: a photo
 * as a small rounded-square thumbnail — the store "logo" on the
 * food/grocery/pharmacy store-list rows, and the product photo on grocery
 * and pharmacy product rows. Shows `fallback` (typically a
 * `ServiceIconChip`) when there is no photo or it fails to load. Photos
 * are cover-cropped to the square, so a 16:9 store banner shows its
 * centre.
 */
export function PhotoThumbnail({ imageUrl, fallback, size = 56 }: PhotoThumbnailProps) {
  const url = imageUrl?.trim() ?? '';
  const [failed, setFailed] = useState(false);

  if (!url || failed) {
    return (
      <View style={{ width: size, height: size }} className="items-center justify-center">
        {fallback}
      </View>
    );
  }

  return (
    <View style={{ width: size, height: size, borderRadius: radius.lg }} className="overflow-hidden">
      <Image
        source={{ uri: url }}
        style={{ width: size, height: size }}
        contentFit="cover"
        cachePolicy="memory-disk"
        onError={() => setFailed(true)}
      />
    </View>
  );
}
