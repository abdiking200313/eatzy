import { Text, View } from 'react-native';

/**
 * Dev-only token gallery for issue #352 (NativeWind theme tokens, light and
 * dark). Not a port of a specific Flutter screen — it exists purely to
 * exercise the color/spacing/radius/shadow/typography tokens from
 * tailwind.config.js side by side, in both color schemes, before the full
 * dev gallery lands in issue #357.
 */
export function ThemeTokenGallery() {
  return (
    <View className="gap-x6">
      <View className="gap-x3">
        <Text className="text-sectionTitle text-text">Semantic colors</Text>
        <View className="flex-row flex-wrap gap-x2">
          <Swatch className="bg-bg" label="bg" />
          <Swatch className="bg-bgMuted" label="bgMuted" />
          <Swatch className="bg-card" label="card" />
          <Swatch className="bg-cardMuted" label="cardMuted" />
          <Swatch className="bg-searchFill" label="searchFill" />
          <Swatch className="bg-border" label="border" />
          <Swatch className="bg-borderStrong" label="borderStrong" />
          <Swatch className="bg-primary" label="primary" dark />
          <Swatch className="bg-primaryHover" label="primaryHover" dark />
          <Swatch className="bg-primarySoft" label="primarySoft" />
          <Swatch className="bg-primaryAccent" label="primaryAccent" dark />
          <Swatch className="bg-secondary" label="secondary" dark />
          <Swatch className="bg-secondarySoft" label="secondarySoft" />
          <Swatch className="bg-tertiary" label="tertiary" dark />
          <Swatch className="bg-error" label="error" dark />
          <Swatch className="bg-errorSoft" label="errorSoft" />
        </View>
      </View>

      <View className="gap-x3">
        <Text className="text-sectionTitle text-text">Typography</Text>
        <Text className="text-text3xl text-text">text3xl</Text>
        <Text className="text-text2xl text-text">text2xl</Text>
        <Text className="text-textXl text-text">textXl</Text>
        <Text className="text-textLg text-text">textLg</Text>
        <Text className="text-textBase text-text">textBase</Text>
        <Text className="text-textSm text-textMuted">textSm (muted)</Text>
        <Text className="text-textXs text-text">textXs</Text>
        <Text className="text-fontBoldSm text-text">fontBoldSm</Text>
        <Text className="text-fontBoldBase text-text">fontBoldBase</Text>
        <Text className="text-link text-primary">link</Text>
        <Text className="text-sectionLabel text-textMuted">SECTION LABEL</Text>
      </View>

      <View className="gap-x3">
        <Text className="text-sectionTitle text-text">
          Radius &amp; shadow
        </Text>
        <View className="flex-row flex-wrap gap-x3">
          <View className="h-x12 w-x12 items-center justify-center rounded-sm bg-card shadow-card">
            <Text className="text-textXs text-textMuted">sm</Text>
          </View>
          <View className="h-x12 w-x12 items-center justify-center rounded-lg bg-card shadow-card">
            <Text className="text-textXs text-textMuted">lg</Text>
          </View>
          <View className="h-x12 w-x12 items-center justify-center rounded-card bg-card shadow-panel">
            <Text className="text-textXs text-textMuted">card</Text>
          </View>
          <View className="h-x12 w-x12 items-center justify-center rounded-hero bg-primarySoft shadow-header">
            <Text className="text-textXs text-textMuted">hero</Text>
          </View>
        </View>
        <View className="items-center justify-center rounded-lg bg-primary px-x4 py-x3 shadow-button">
          <Text className="text-button text-onPrimary">Primary button</Text>
        </View>
      </View>
    </View>
  );
}

function Swatch({
  className,
  label,
  dark = false,
}: {
  className: string;
  label: string;
  dark?: boolean;
}) {
  return (
    <View
      className={`w-24 items-center gap-x1 rounded-md border border-border p-x2 ${className}`}>
      <Text className={dark ? 'text-textXs text-onPrimary' : 'text-textXs text-text'}>
        {label}
      </Text>
    </View>
  );
}
