import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { useServiceTheme } from '@/hooks/use-service-theme';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import type { ServiceId } from '@/theme/service-theme';
import { rawColors, spacing } from '@/theme/tokens';

/**
 * `kStoreHeroAppBarHeight` in store_hero_app_bar.dart: the fixed height of
 * the photo hero atop a single store/restaurant screen — shared by the
 * (not yet ported) restaurant/grocery-store/pharmacy-catalog screens so the
 * three read as visually consistent.
 */
export const STORE_HERO_APP_BAR_HEIGHT = 230;

export type StoreHeroAppBarProps = {
  title: string;
  imageUrl?: string | null;
  /** Shown in a plain tile when there's no photo (or it fails to load). */
  fallbackIcon: keyof typeof MaterialIcons.glyphMap;
  /**
   * Food's restaurant logo is letterboxed ('contain') rather than cropped,
   * unlike grocery's/pharmacy's store photos ('cover'). Maps 1:1 to
   * `expo-image`'s `contentFit` values.
   */
  imageFit?: 'cover' | 'contain';
  actions?: ReactNode;
  /**
   * Adds an explicit back button. The restaurant screen leaves this false
   * and relies on Expo Router's own stack header/gesture instead, same as
   * the Flutter source relying on the default automatic back button there.
   */
  showBackButton?: boolean;
  /**
   * Called when the back button is pressed. This component stays
   * presentational (no navigation logic here, unlike the Flutter source's
   * own embedded `context.canPop() ? context.pop() : context.go(AppRoutes.mainApp)`)
   * — the screen that renders this wires it to real navigation. Required
   * whenever `showBackButton` is true.
   */
  onBackPress?: () => void;
  /**
   * Which service's accent palette this bar/fallback tile themes, mirroring
   * the Flutter widget reading the ambient `ZivoServiceTheme` via
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
 * Ports flutter_app/lib/widgets/store_hero_app_bar.dart's `StoreHeroAppBar`:
 * the photo-hero header atop a single store/restaurant screen — an
 * accent-colored bar with the store's name, a full-bleed photo (or a
 * fallback icon tile when there's none/it fails to load) darkened by a
 * gradient so the title stays legible, and optional trailing `actions`
 * (e.g. the cart badge). Shared by the restaurant, grocery-store, and
 * pharmacy-catalog screens (not yet ported).
 *
 * Unlike the Flutter `SliverAppBar` this ports, this renders only the
 * static hero + title bar at `STORE_HERO_APP_BAR_HEIGHT` — there is no
 * React Native equivalent of a pinned/collapsing sliver at this
 * presentational-component level. The screen that hosts this (a future
 * vertical-screen issue) decides how to scroll content under/past it.
 */
export function StoreHeroAppBar({
  title,
  imageUrl,
  fallbackIcon,
  imageFit = 'cover',
  actions,
  showBackButton = false,
  onBackPress,
  service = 'unknown',
  slug,
  testID,
}: StoreHeroAppBarProps) {
  const palette = useServiceTheme(service, slug);
  const colors = useSemanticColors();

  return (
    <View
      testID={testID}
      style={{ height: STORE_HERO_APP_BAR_HEIGHT, backgroundColor: palette.accent, overflow: 'hidden' }}>
      <StoreHero imageUrl={imageUrl} fallbackIcon={fallbackIcon} fit={imageFit} accentColor={palette.accent} cardColor={colors.card} />
      <GradientScrim />
      <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 0, left: 0, right: 0 }}>
        <View style={{ height: 56, paddingHorizontal: spacing.x2 }} className="flex-row items-center">
          {showBackButton && (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Back"
              onPress={onBackPress}
              className="h-x10 w-x10 items-center justify-center active:opacity-70">
              <MaterialIcons name="arrow-back" size={24} color={palette.onAccent} />
            </Pressable>
          )}
          <Text
            style={{ marginLeft: showBackButton ? 0 : spacing.x4, color: palette.onAccent }}
            className="flex-1 text-fontBoldBase font-outfitSemiBold"
            numberOfLines={1}>
            {title}
          </Text>
          {actions && <View className="flex-row items-center">{actions}</View>}
        </View>
      </SafeAreaView>
    </View>
  );
}

/** Top-to-bottom scrim, darker at the top (where the pinned title sits)
 * fading to lighter near the bottom, so the title stays legible over any
 * photo while the photo itself still reads through lower down. Matches the
 * Dart `LinearGradient`'s `topCenter`->`bottomCenter` `slate900` stops at
 * `85/255`->`34/255` opacity exactly. */
function GradientScrim() {
  return (
    <Svg style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} width="100%" height="100%">
      <Defs>
        <LinearGradient id="storeHeroGradient" x1="0%" y1="0%" x2="0%" y2="100%">
          <Stop offset="0" stopColor={rawColors.slate900} stopOpacity={85 / 255} />
          <Stop offset="1" stopColor={rawColors.slate900} stopOpacity={34 / 255} />
        </LinearGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#storeHeroGradient)" />
    </Svg>
  );
}

function StoreHero({
  imageUrl,
  fallbackIcon,
  fit,
  accentColor,
  cardColor,
}: {
  imageUrl?: string | null;
  fallbackIcon: keyof typeof MaterialIcons.glyphMap;
  fit: 'cover' | 'contain';
  accentColor: string;
  cardColor: string;
}) {
  const url = imageUrl?.trim() ?? '';
  const [status, setStatus] = useState<'loading' | 'loaded' | 'error'>(url ? 'loading' : 'error');

  return (
    <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}>
      {/* A plain base color under the photo: a logo/photo with transparent
          pixels (common for uploaded restaurant/store logos) would
          otherwise reveal whatever sits behind this in the component tree —
          the bar's own accent color — which would read as a stray color
          bleed-through around/through the image rather than a clean
          background. */}
      <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: cardColor }} />
      {/* Mirrors the Dart `CachedNetworkImage`'s `placeholder`/`errorWidget`
          fully replacing the image while loading/on error: the fallback
          tile stays visible (with a spinner while loading, no spinner on
          error) until the photo finishes loading, rather than revealing it
          progressively. Harmless to leave mounted once loaded too — the
          opaque, loaded `Image` fully covers it. The `Image` itself is
          still mounted (at `opacity: 0`) while loading so its
          `onLoad`/`onError` callbacks can fire. */}
      <StoreHeroFallback icon={fallbackIcon} accentColor={accentColor} cardColor={cardColor} showLoader={status === 'loading'} />
      {url && (
        <Image
          source={{ uri: url }}
          style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, opacity: status === 'loaded' ? 1 : 0 }}
          contentFit={fit}
          cachePolicy="memory-disk"
          onLoad={() => setStatus('loaded')}
          onError={() => setStatus('error')}
        />
      )}
    </View>
  );
}

function StoreHeroFallback({
  icon,
  accentColor,
  cardColor,
  showLoader,
}: {
  icon: keyof typeof MaterialIcons.glyphMap;
  accentColor: string;
  cardColor: string;
  showLoader: boolean;
}) {
  return (
    <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: cardColor }} className="items-center justify-center">
      {showLoader ? <ActivityIndicator color={accentColor} /> : <MaterialIcons name={icon} size={72} color={accentColor} />}
    </View>
  );
}
