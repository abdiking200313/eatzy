import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import type { ServiceDescriptor } from '@/platform/services/registry';
import { rawColors, radius, spacing } from '@/theme/tokens';

export type ServiceGridProps = {
  modules: ServiceDescriptor[];
  onModulePress: (module: ServiceDescriptor) => void;
  onMore: () => void;
};

/**
 * Ports `flutter_app/lib/features/super_app/presentation/widgets/service_grid.dart`'s
 * `ServiceGrid`: a three-column grid of photo tiles, the live service
 * modules then a trailing "More" tile that opens the full Services list.
 *
 * A plain flex-wrap row, not a virtualized grid -- the Dart source's own
 * `GridView.builder` is `shrinkWrap`/`NeverScrollableScrollPhysics` (not
 * independently scrollable either), so there's no virtualization
 * behavior to preserve, just a fixed small tile count.
 */
export function ServiceGrid({ modules, onModulePress, onMore }: ServiceGridProps) {
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.gridGap }}>
      {modules.map((module) => (
        <CategoryTile
          key={module.slug}
          testID={`service-${module.slug}`}
          icon={module.icon}
          photoUrl={module.photoUrl}
          label={module.title}
          onPress={() => onModulePress(module)}
        />
      ))}
      <CategoryTile testID="service-more" icon="grid-view" label="More" onPress={onMore} />
    </View>
  );
}

const TILE_HEIGHT = 96;

function CategoryTile({
  testID,
  icon,
  photoUrl,
  label,
  onPress,
}: {
  testID: string;
  icon: keyof typeof MaterialIcons.glyphMap;
  photoUrl?: string;
  label: string;
  onPress: () => void;
}) {
  const [photoFailed, setPhotoFailed] = useState(false);
  const showPhoto = !!photoUrl && !photoFailed;

  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={{ width: '31%', height: TILE_HEIGHT, borderRadius: radius.tile, overflow: 'hidden', backgroundColor: rawColors.stone100 }}
      className="active:opacity-80">
      {showPhoto ? (
        <PhotoTileContent photoUrl={photoUrl} label={label} onPhotoError={() => setPhotoFailed(true)} />
      ) : (
        <IconTileContent icon={icon} label={label} />
      )}
    </Pressable>
  );
}

function PhotoTileContent({
  photoUrl,
  label,
  onPhotoError,
}: {
  photoUrl: string;
  label: string;
  onPhotoError: () => void;
}) {
  return (
    <View style={{ flex: 1 }}>
      <Image source={{ uri: photoUrl }} style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} contentFit="cover" cachePolicy="memory-disk" onError={onPhotoError} />
      {/* The Dart source darkens only the bottom ~55% with a gradient; this
          flat scrim is a visual simplification (not a behavior the
          acceptance criteria call out) rather than another SVG gradient
          layer for a tile this small. */}
      <View style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: '55%', backgroundColor: 'rgba(15, 23, 42, 0.5)' }} />
      <View style={{ position: 'absolute', left: spacing.x2_5, right: spacing.x2_5, bottom: spacing.x2_5 }}>
        <TileLabel label={label} color={rawColors.white} />
      </View>
    </View>
  );
}

function IconTileContent({ icon, label }: { icon: keyof typeof MaterialIcons.glyphMap; label: string }) {
  return (
    <View style={{ flex: 1, padding: spacing.x2_5, justifyContent: 'space-between' }}>
      <MaterialIcons name={icon} size={28} color={rawColors.slate700} />
      <TileLabel label={label} color={rawColors.slate900} />
    </View>
  );
}

function TileLabel({ label, color }: { label: string; color: string }) {
  return (
    <Text style={{ color }} className="text-fontBoldSm" numberOfLines={1}>
      {label}
    </Text>
  );
}
