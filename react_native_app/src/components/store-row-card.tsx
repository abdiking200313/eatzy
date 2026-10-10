import { MaterialIcons } from '@expo/vector-icons';
import { Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { PhotoThumbnail } from '@/components/photo-thumbnail';
import { ServiceIconChip } from '@/components/service-icon-chip';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import type { ServiceId } from '@/theme/service-theme';
import { radius, spacing } from '@/theme/tokens';

export type StoreRowCardProps = {
  imageUrl?: string | null;
  fallbackIcon: keyof typeof MaterialIcons.glyphMap;
  name: string;
  /**
   * Extra muted lines under the name, e.g. a description or address.
   * Callers filter out blank values before passing them in.
   */
  subtitleLines?: string[];
  subtitleMaxLines?: number;
  /**
   * A trailing muted caption below the subtitle lines, e.g. grocery's
   * "N products" count.
   */
  caption?: string;
  onPress: () => void;
  /**
   * Which service's accent palette themes the fallback icon chip,
   * mirroring the Flutter widget reading the ambient `ZivoServiceTheme` via
   * `context.serviceColors`. There is no such ambient theme in this app yet
   * (see src/hooks/use-service-theme.ts), so the caller passes its own
   * `ServiceId` explicitly; omit for the neutral platform palette.
   */
  service?: ServiceId;
  /** See `useServiceTheme`'s `slug` param (e.g. Fresh Meat, Electronics). */
  slug?: string;
  testID?: string;
};

/**
 * Ports flutter_app/lib/widgets/store_row_card.dart's `StoreRowCard`: a
 * tappable store/restaurant row on a store-list screen — a photo thumbnail
 * (or a fallback icon tile when there's none), the store's name, one or
 * more muted subtitle lines, an optional trailing caption below them (e.g.
 * grocery's product count), and a trailing chevron. Shared by food's
 * restaurant list, grocery's store list, and pharmacy's store list so the
 * three verticals' store rows read as one consistent pattern.
 */
export function StoreRowCard({
  imageUrl,
  fallbackIcon,
  name,
  subtitleLines = [],
  subtitleMaxLines = 1,
  caption,
  onPress,
  service = 'unknown',
  slug,
  testID,
}: StoreRowCardProps) {
  const colors = useSemanticColors();

  return (
    <OutlinedCard testID={testID} borderRadius={radius.card} padding={0} onPress={onPress}>
      <View style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3 }} className="flex-row items-center">
        <PhotoThumbnail
          imageUrl={imageUrl}
          size={60}
          fallback={<ServiceIconChip icon={fallbackIcon} iconSize={28} service={service} slug={slug} />}
        />
        <View style={{ width: spacing.x3_5 }} />
        <View style={{ flex: 1 }}>
          <Text className="text-fontBoldBase font-outfitSemiBold text-text" numberOfLines={1}>
            {name}
          </Text>
          {subtitleLines.map((line, index) => (
            // `3` on the first line matches the Dart `SizedBox(height: 3)`
            // literally — not a `TwSpacing` token on that side either.
            <Text
              key={index}
              style={{ marginTop: index === 0 ? 3 : spacing.x2, color: colors.textMuted }}
              className="text-textSm font-outfitRegular"
              numberOfLines={subtitleMaxLines}>
              {line}
            </Text>
          ))}
          {caption != null && (
            <Text
              style={{ marginTop: subtitleLines.length === 0 ? 3 : spacing.x2, color: colors.textMuted }}
              className="text-textXs font-outfitMedium">
              {caption}
            </Text>
          )}
        </View>
        <View style={{ width: spacing.x2 }} />
        <MaterialIcons name="chevron-right" size={24} color={colors.textMuted} />
      </View>
    </OutlinedCard>
  );
}
