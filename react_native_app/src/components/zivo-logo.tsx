import { useId } from 'react';
import { Text, useColorScheme, View } from 'react-native';
import Svg, { Defs, LinearGradient, Path, Stop } from 'react-native-svg';

import { colors, rawColors } from '@/theme/tokens';

/**
 * Ports flutter_app/lib/widgets/zivo_logo.dart's `ZivoBrand`: the single
 * source of the product name shown next to/under the mark.
 */
export const ZivoBrand = {
  name: 'Zivo',
} as const;

export type ZivoLogoProps = {
  height?: number;
  showWordmark?: boolean;
  wordmarkColor?: string;
};

/**
 * Ports flutter_app/lib/widgets/zivo_logo.dart's `ZivoLogo`: the brand mark
 * (a gradient "Z" glyph, painted by `ZivoMarkPainter` there) stacked above
 * an optional "zivo" wordmark.
 *
 * The Flutter `CustomPainter` draws the glyph as fractions of its own
 * `size.width`/`size.height`; `ZivoMark` below reproduces the exact same
 * path as an SVG `viewBox="0 0 100 100"`, so every coordinate is just the
 * Dart fraction * 100.
 */
export function ZivoLogo({ height = 38, showWordmark = true, wordmarkColor }: ZivoLogoProps) {
  // Flutter's default (`TwColors.text`) is a light-mode-only constant —
  // flutter_app has no dark `ThemeData` yet. This prop takes a literal
  // color rather than a className (its size is computed from `height`), so
  // the scheme-aware default is resolved here instead, matching the
  // semantic `text` token's light/dark values in theme/tokens.ts.
  const scheme = useColorScheme();
  const resolvedWordmarkColor = wordmarkColor ?? colors[scheme === 'dark' ? 'dark' : 'light'].text;

  return (
    <View
      accessible
      accessibilityRole="image"
      accessibilityLabel={ZivoBrand.name}
      className="items-center">
      <ZivoMark size={height} />
      {showWordmark && (
        <Text
          style={{
            // `height * 0.42`/`height * 0.06` and `letterSpacing: -0.4` are
            // the Flutter widget's own proportional sizing, not tokens —
            // kept as literal math here to match 1:1 rather than snapping
            // to the nearest fixed `text-*` scale step.
            marginTop: height * 0.06,
            fontSize: height * 0.42,
            color: resolvedWordmarkColor,
            letterSpacing: -0.4,
            lineHeight: height * 0.42,
          }}
          className="font-outfitBold">
          zivo
        </Text>
      )}
    </View>
  );
}

/**
 * Ports flutter_app/lib/widgets/zivo_logo.dart's `ZivoMarkPainter`: a
 * blue400 -> blue700, top-left to bottom-right gradient "Z" glyph. Exported
 * so it can be reused outside `ZivoLogo` the same way the Flutter painter
 * is reused by `tool/generate_brand_assets.dart`.
 */
export function ZivoMark({ size }: { size: number }) {
  // Unique per instance so two logos on screen at once (e.g. on
  // react-native-web, which renders real SVG DOM nodes) don't collide on
  // the same `id` when resolving `url(#...)`.
  const gradientId = `zivo-mark-gradient-${useId()}`;

  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <Defs>
        <LinearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <Stop offset="0" stopColor={rawColors.blue400} />
          <Stop offset="1" stopColor={rawColors.blue700} />
        </LinearGradient>
      </Defs>
      <Path
        fill={`url(#${gradientId})`}
        d="M18,13 Q20,5 30,5 L79,5 Q94,5 94,20 Q94,28 86,34 L34,72 L80,72 Q91,72 86,82 L81,91 L29,91 Q8,91 8,72 Q8,61 19,53 L68,18 L20,18 Q14,18 18,13 Z"
      />
    </Svg>
  );
}
