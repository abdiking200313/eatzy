import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { useState } from 'react';
import { ActivityIndicator, Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, rawColors, spacing } from '@/theme/tokens';

export type StoreListCardProps = {
  name: string;
  subtitle: string;
  /** Null/empty renders the "No picture available" placeholder rather than
   * a generic icon substitute — an explicit product requirement, not a
   * fallback to skip visually. */
  imageUrl?: string | null;
  accentColor: string;
  onPress: () => void;
};

// `_StoreListImage.height` in app_cards.dart.
const IMAGE_HEIGHT = 138;

/**
 * Ports flutter_app/lib/widgets/app_cards.dart's `StoreListCard`: a
 * photo-header list card for a single store, used in mixed-vertical
 * contexts (the home screen's "Popular Stores" strip, the Explore feed).
 * Distinct from `StoreRowCard` (not ported here — a separate, compact row
 * used by each vertical's own single-vertical store list, not listed among
 * this issue's ported files).
 */
export function StoreListCard({ name, subtitle, imageUrl, accentColor, onPress }: StoreListCardProps) {
  const colors = useSemanticColors();

  return (
    <OutlinedCard
      backgroundColor={colors.card}
      borderRadius={radius.media}
      borderColor={colors.border}
      padding={0}
      onPress={onPress}>
      <StoreListImage imageUrl={imageUrl} accentColor={accentColor} />
      <View style={{ paddingTop: spacing.x2_5, paddingBottom: spacing.x3, paddingHorizontal: spacing.x3 }}>
        <Text className="text-fontBoldSm font-outfitSemiBold text-text" numberOfLines={1}>
          {name}
        </Text>
        {/* `3` matches the Dart `SizedBox(height: 3)` literally — not a
            `TwSpacing` token on that side either. */}
        <View style={{ marginTop: 3 }} className="flex-row items-center">
          {/* The one accent touch this neutral white card allows — a small
              service-colored dot next to the subtitle, mirroring how the
              accent stays confined to a small element elsewhere (e.g. the
              service icon chip). */}
          <View style={{ backgroundColor: accentColor }} className="h-1.5 w-1.5 rounded-full" />
          <Text
            style={{ marginLeft: spacing.x1 }}
            className="shrink text-textXs font-outfitMedium text-textMuted"
            numberOfLines={1}>
            {subtitle}
          </Text>
        </View>
      </View>
    </OutlinedCard>
  );
}

function StoreListImage({
  imageUrl,
  accentColor,
}: {
  imageUrl?: string | null;
  accentColor: string;
}) {
  const url = imageUrl?.trim() ?? '';
  const [status, setStatus] = useState<'loading' | 'loaded' | 'error'>(url ? 'loading' : 'error');

  if (!url || status === 'error') {
    return <NoPicturePlaceholder />;
  }

  return (
    <View style={{ height: IMAGE_HEIGHT }} className="w-full">
      <Image
        source={{ uri: url }}
        style={{ height: IMAGE_HEIGHT, width: '100%' }}
        contentFit="cover"
        cachePolicy="memory-disk"
        onLoad={() => setStatus('loaded')}
        onError={() => setStatus('error')}
      />
      {status === 'loading' && (
        <View
          style={{ backgroundColor: withAlpha(accentColor, 0.08) }}
          className="absolute inset-0 items-center justify-center">
          <ActivityIndicator color={accentColor} />
        </View>
      )}
    </View>
  );
}

/**
 * The explicit "no photo" state for `StoreListCard` — a neutral gray box
 * with a broken-image icon and a small muted caption, never a generic
 * service icon standing in for a missing photo.
 */
function NoPicturePlaceholder() {
  const colors = useSemanticColors();

  return (
    <View
      style={{ height: IMAGE_HEIGHT, backgroundColor: rawColors.stone100 }}
      className="w-full items-center justify-center">
      <MaterialIcons name="broken-image" size={28} color={colors.textMuted} />
      <Text style={{ marginTop: spacing.x2 }} className="text-textXs font-outfitMedium text-textMuted">
        No picture available
      </Text>
    </View>
  );
}

function withAlpha(hex: string, alpha: number): string {
  const normalized = hex.replace('#', '');
  const value = normalized.length === 3
    ? normalized
        .split('')
        .map((char) => char + char)
        .join('')
    : normalized;
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}
