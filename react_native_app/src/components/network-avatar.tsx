import { Image } from 'expo-image';
import { useState } from 'react';
import { View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

export type NetworkAvatarProps = {
  imageUrl: string;
  radius?: number;
};

/**
 * Ports flutter_app/lib/widgets/app_misc.dart's `NetworkAvatar`: a circular
 * avatar that loads an image from the network with a graceful fallback
 * (Flutter's bare `CircleAvatar`, no `backgroundImage`) while loading or on
 * error.
 */
export function NetworkAvatar({ imageUrl, radius = 25 }: NetworkAvatarProps) {
  const colors = useSemanticColors();
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);
  const dimension = radius * 2;
  const showImage = imageUrl.length > 0 && !failed;

  return (
    <View
      style={{ width: dimension, height: dimension, borderRadius: radius, backgroundColor: colors.cardMuted }}
      className="items-center justify-center overflow-hidden">
      {showImage && (
        <Image
          source={{ uri: imageUrl }}
          style={{ width: dimension, height: dimension, opacity: loaded ? 1 : 0 }}
          contentFit="cover"
          cachePolicy="memory-disk"
          onLoad={() => setLoaded(true)}
          onError={() => setFailed(true)}
        />
      )}
    </View>
  );
}
