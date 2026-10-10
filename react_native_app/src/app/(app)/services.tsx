/**
 * Ports `flutter_app/lib/features/super_app/presentation/categories_screen.dart`
 * (issue #374 / P4-03): the Services list, rendering every tile from
 * `ServiceRegistry` (issue #371) plus the coming-soon placeholders.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { router } from 'expo-router';
import { useState } from 'react';
import { FlatList, Text, View } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { AppScaffold } from '@/components/app-scaffold';
import { CartSnackbar } from '@/components/cart-snackbar';
import { OutlinedCard } from '@/components/outlined-card';
import { StatusPill } from '@/components/status-pill';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { ServiceRegistry, type ComingSoonCategory, type ServiceDescriptor } from '@/platform/services/registry';
import { ServiceThemes } from '@/theme/service-theme';
import { radius, rawColors, spacing } from '@/theme/tokens';

type ListEntry =
  | { kind: 'module'; module: ServiceDescriptor }
  | { kind: 'comingSoon'; category: ComingSoonCategory };

const ENTRIES: ListEntry[] = [
  ...ServiceRegistry.modules.map((module): ListEntry => ({ kind: 'module', module })),
  ...ServiceRegistry.comingSoon.map((category): ListEntry => ({ kind: 'comingSoon', category })),
];

export default function ServicesScreen({ showBackButton = true }: { showBackButton?: boolean }) {
  const snackbar = useCartSnackbar();

  return (
    <AppScaffold title="Services" showBackButton={showBackButton}>
      <View style={{ flex: 1 }}>
        <FlatList
          data={ENTRIES}
          keyExtractor={(entry) => (entry.kind === 'module' ? `module-${entry.module.slug}` : `coming-soon-${entry.category.id}`)}
          contentContainerStyle={{
            paddingHorizontal: spacing.x5,
            paddingTop: spacing.x5,
            paddingBottom: spacing.x6,
          }}
          ItemSeparatorComponent={() => <View style={{ height: spacing.x5 }} />}
          renderItem={({ item }) =>
            item.kind === 'module' ? (
              <ModuleCard module={item.module} />
            ) : (
              <ComingSoonCard category={item.category} onComingSoon={snackbar.show} />
            )
          }
        />
        <CartSnackbar message={snackbar.message} />
      </View>
    </AppScaffold>
  );
}

function ModuleCard({ module }: { module: ServiceDescriptor }) {
  const palette = useServiceTheme(module.id, module.slug);

  return (
    <ServicePhotoCard
      testID={`services-${module.slug}`}
      title={module.title}
      description={module.description}
      icon={module.icon}
      photoUrl={module.photoUrl}
      accentColor={palette.accent}
      // Not a push: module.entryRoute belongs to its own shell branch (see
      // (tabs)/_layout.tsx), so this switches branches within the
      // persistent bottom-nav shell instead of stacking a full-screen route
      // over it and hiding the nav bar.
      onPress={() => router.replace(module.entryRoute as never)}
    />
  );
}

function ComingSoonCard({ category, onComingSoon }: { category: ComingSoonCategory; onComingSoon: (message: string) => void }) {
  const platform = ServiceThemes.platform;

  return (
    <ServicePhotoCard
      testID={`services-coming-soon-${category.id}`}
      title={category.title}
      description={category.description}
      icon={category.icon}
      photoUrl={category.photoUrl}
      accentColor={platform.accent}
      comingSoon
      onPress={() => onComingSoon(`${category.title} is coming soon`)}
    />
  );
}

const CARD_HEIGHT = 148;

type ServicePhotoCardProps = {
  testID: string;
  title: string;
  description: string;
  icon: keyof typeof MaterialIcons.glyphMap;
  photoUrl?: string;
  accentColor: string;
  onPress: () => void;
  comingSoon?: boolean;
};

/**
 * A full-bleed photo card for a service/category: a real photo (when
 * `photoUrl` is set) or a locally-drawn accent-gradient placeholder with a
 * large low-opacity icon watermark (when it isn't), with a bottom gradient
 * scrim and white title/description text on top. `comingSoon` dims the
 * whole card so it reads as disabled.
 *
 * The Flutter source desaturates (`ColorFiltered`/grayscale matrix) a
 * coming-soon card; React Native has no built-in grayscale filter without
 * an extra native dependency, so this approximates it with reduced
 * opacity instead -- a visual simplification, not a behavior change (the
 * card is still fully readable and tappable).
 */
function ServicePhotoCard({ testID, title, description, icon, photoUrl, accentColor, onPress, comingSoon = false }: ServicePhotoCardProps) {
  const [photoFailed, setPhotoFailed] = useState(false);
  const showPhoto = !!photoUrl && !photoFailed;

  return (
    <OutlinedCard
      testID={testID}
      padding={0}
      borderRadius={radius.card}
      borderColor={comingSoon ? rawColors.stone300 : undefined}
      onPress={onPress}>
      <View style={{ height: CARD_HEIGHT, opacity: comingSoon ? 0.6 : 1 }}>
        {showPhoto ? (
          <Image
            source={{ uri: photoUrl }}
            style={{ height: CARD_HEIGHT, width: '100%' }}
            contentFit="cover"
            cachePolicy="memory-disk"
            onError={() => setPhotoFailed(true)}
          />
        ) : (
          <PhotoPlaceholder icon={icon} accentColor={accentColor} />
        )}

        <GradientScrim />

        <View style={{ position: 'absolute', left: spacing.x4, right: spacing.x4, bottom: spacing.x4 }}>
          <Text className="font-outfitBold text-fontBoldBase text-white" numberOfLines={1}>
            {title}
          </Text>
          <Text style={{ marginTop: spacing.x2 }} className="text-textSm text-white/85" numberOfLines={2}>
            {description}
          </Text>
          {comingSoon && (
            <View style={{ marginTop: spacing.x2 }}>
              <StatusPill label="Coming soon" backgroundColor={rawColors.white} foregroundColor={rawColors.slate700} fontSize={11} />
            </View>
          )}
        </View>
      </View>
    </OutlinedCard>
  );
}

/** Bottom-to-top transparent -> black scrim so white text stays legible
 * over any photo or placeholder. */
function GradientScrim() {
  return (
    <Svg style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} width="100%" height="100%">
      <Defs>
        <LinearGradient id="servicesCardScrim" x1="0%" y1="0%" x2="0%" y2="100%">
          <Stop offset="0.4" stopColor="#000000" stopOpacity={0} />
          <Stop offset="1" stopColor="#000000" stopOpacity={0.8} />
        </LinearGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#servicesCardScrim)" />
    </Svg>
  );
}

/** A locally-drawn placeholder background for a category with no real
 * photo yet: a soft gradient in the category's own accent color with a
 * large, low-opacity watermark of its icon. */
function PhotoPlaceholder({ icon, accentColor }: { icon: keyof typeof MaterialIcons.glyphMap; accentColor: string }) {
  return (
    <View style={{ height: CARD_HEIGHT, width: '100%' }}>
      <Svg style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} width="100%" height="100%">
        <Defs>
          <LinearGradient id="servicesCardPlaceholder" x1="0%" y1="0%" x2="100%" y2="100%">
            <Stop offset="0" stopColor={accentColor} stopOpacity={0.55} />
            <Stop offset="1" stopColor={accentColor} stopOpacity={0.85} />
          </LinearGradient>
        </Defs>
        <Rect width="100%" height="100%" fill="url(#servicesCardPlaceholder)" />
      </Svg>
      <View style={{ position: 'absolute', right: spacing.x2, top: 0, bottom: 0 }} className="items-center justify-center">
        <MaterialIcons name={icon} size={120} color="rgba(255, 255, 255, 0.18)" />
      </View>
    </View>
  );
}
