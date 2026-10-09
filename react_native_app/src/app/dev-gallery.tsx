import { Redirect } from 'expo-router';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { ScrollView, Text, View } from 'react-native';

import { AddToCartButton } from '@/components/add-to-cart-button';
import { AppSearchBar } from '@/components/app-search-bar';
import { AppTextField } from '@/components/app-text-field';
import { AuthCard } from '@/components/auth-card';
import { CartAppBarAction } from '@/components/cart-app-bar-action';
import { CartSnackbar } from '@/components/cart-snackbar';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { GradientActionButton } from '@/components/gradient-action-button';
import { LoadingState } from '@/components/loading-state';
import { NetworkAvatar } from '@/components/network-avatar';
import { OutlinedCard } from '@/components/outlined-card';
import { PhotoThumbnail } from '@/components/photo-thumbnail';
import { PrimaryButton } from '@/components/primary-button';
import { SectionTitle } from '@/components/section-title';
import { ServiceIconChip } from '@/components/service-icon-chip';
import { ServicePhotoChip } from '@/components/service-photo-chip';
import { StatusPill } from '@/components/status-pill';
import { StoreListCard } from '@/components/store-list-card';
import { SummaryRow } from '@/components/summary-row';
import { ThemeTokenGallery } from '@/components/theme-token-gallery';
import { ZivoLogo } from '@/components/zivo-logo';
import { useSemanticColors } from '@/hooks/use-semantic-colors';

/**
 * Dev-only gallery of every shared component in `src/components/` (issue
 * #357), the component-library counterpart of `theme-preview.tsx`'s token
 * gallery (#352/#353) — one screen to visually review every port from
 * `flutter_app/lib/widgets/**` plus the new `LoadingState`/`EmptyState`/
 * `ErrorState` trio (ported from the *shape* every screen driven by
 * `flutter_app/lib/services/shared/presentation/loadable_state_mixin.dart`
 * already repeats, not a single Flutter widget file — see those
 * components' own doc comments) side by side, in whichever color scheme the
 * OS is in (this app has no in-app theme toggle yet — see
 * `tailwind.config.js`'s `darkMode: 'media'` — so switch the OS appearance
 * to see the dark variant).
 *
 * Gated on the `__DEV__` global (true for `expo start`/a dev client build,
 * false for a production `expo export`/EAS build — see
 * https://docs.expo.dev/workflow/expo-cli/#opening-the-app) so this never
 * ships reachable in a production bundle: a production build hitting this
 * route (e.g. a stale deep link) immediately redirects home instead of
 * rendering. Excludes `src/components/ui/**` and the plain Expo-template
 * leftovers (`web-badge`, `hint-row`, `external-link`, `themed-text`,
 * `themed-view`, `animated-icon`, `app-tabs`) that predate this design
 * system and don't use its tokens.
 */
export default function DevGalleryScreen() {
  // Hooks must run unconditionally on every render (rules-of-hooks) even
  // though `__DEV__` itself never changes within a running bundle -- the
  // production early-return below has to come after them.
  const colors = useSemanticColors();
  const [searchText, setSearchText] = useState('');
  const [fieldText, setFieldText] = useState('');

  if (!__DEV__) {
    return <Redirect href="/" />;
  }

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="gap-x8 px-screenX py-x6">
      <View className="gap-x2">
        <Text className="text-text3xl font-outfitBold text-text">Component gallery</Text>
        <Text className="text-textSm font-outfitRegular text-textMuted">
          Every shared component in src/components, dev-only (__DEV__). Toggle the OS appearance
          to review light and dark mode.
        </Text>
      </View>

      <Gallery title="Theme tokens">
        <ThemeTokenGallery />
      </Gallery>

      <Gallery title="Loading, empty, and error states">
        <GallerySwatch label="LoadingState (no caption)">
          <View className="overflow-hidden rounded-lg border border-border">
            <LoadingState />
          </View>
        </GallerySwatch>
        <GallerySwatch label="LoadingState (with caption)">
          <View className="overflow-hidden rounded-lg border border-border">
            <LoadingState message="Loading menu…" />
          </View>
        </GallerySwatch>
        <GallerySwatch label="EmptyState">
          <View className="overflow-hidden rounded-lg border border-border">
            <EmptyState
              icon="receipt-long"
              title="No activity yet"
              message="Your orders and bookings will appear here."
            />
          </View>
        </GallerySwatch>
        <GallerySwatch label="ErrorState">
          <View className="overflow-hidden rounded-lg border border-border">
            <ErrorState message="We could not load this page." onRetry={() => {}} />
          </View>
        </GallerySwatch>
      </Gallery>

      <Gallery title="Buttons">
        <GallerySwatch label="PrimaryButton">
          <PrimaryButton label="Save" onPress={() => {}} />
        </GallerySwatch>
        <GallerySwatch label="GradientActionButton">
          <GradientActionButton label="Get Started" onPress={() => {}} />
        </GallerySwatch>
        <GallerySwatch label="AddToCartButton (enabled / disabled)">
          <View className="flex-row gap-x3">
            <AddToCartButton tooltip="Add to cart" onPress={() => {}} />
            <AddToCartButton tooltip="Add to cart" onPress={null} />
          </View>
        </GallerySwatch>
        <GallerySwatch label="CartAppBarAction">
          <View className="flex-row gap-x3">
            <CartAppBarAction itemCount={0} onPress={() => {}} tooltip="Cart" service="food" />
            <CartAppBarAction itemCount={3} onPress={() => {}} tooltip="Cart" service="food" />
          </View>
        </GallerySwatch>
      </Gallery>

      <Gallery title="Cards">
        <GallerySwatch label="OutlinedCard">
          <OutlinedCard>
            <Text className="text-textBase font-outfitRegular text-text">Card content</Text>
          </OutlinedCard>
        </GallerySwatch>
        <GallerySwatch label="AuthCard">
          <AuthCard>
            <Text className="text-textBase font-outfitRegular text-text">Form content</Text>
          </AuthCard>
        </GallerySwatch>
        <GallerySwatch label="StoreListCard">
          <View className="self-start" style={{ width: 220 }}>
            <StoreListCard
              name="Corner Bistro"
              subtitle="Fast delivery"
              imageUrl={null}
              accentColor={colors.primary}
              onPress={() => {}}
            />
          </View>
        </GallerySwatch>
      </Gallery>

      <Gallery title="Chips, avatars, and thumbnails">
        <GallerySwatch label="ServiceIconChip">
          <View className="flex-row gap-x3">
            <ServiceIconChip icon="restaurant" service="food" />
            <ServiceIconChip icon="local-grocery-store" service="grocery" />
            <ServiceIconChip icon="local-pharmacy" service="pharmacy" />
          </View>
        </GallerySwatch>
        <GallerySwatch label="ServicePhotoChip">
          <ServicePhotoChip imageUrl="" service="food" />
        </GallerySwatch>
        <GallerySwatch label="NetworkAvatar">
          <NetworkAvatar imageUrl="" />
        </GallerySwatch>
        <GallerySwatch label="PhotoThumbnail (fallback)">
          <PhotoThumbnail imageUrl={null} fallback={<ServiceIconChip icon="storefront" />} />
        </GallerySwatch>
        <GallerySwatch label="StatusPill">
          <View className="flex-row flex-wrap gap-x2">
            <StatusPill label="On the way" icon="local-shipping" />
            <StatusPill label="Delivered" />
          </View>
        </GallerySwatch>
      </Gallery>

      <Gallery title="Text and layout">
        <GallerySwatch label="SectionTitle">
          <SectionTitle title="Section title" />
        </GallerySwatch>
        <GallerySwatch label="SummaryRow">
          <View className="gap-x1">
            <SummaryRow label="Subtotal" value="$12.00" />
            <SummaryRow label="Total" value="$14.50" isBold />
          </View>
        </GallerySwatch>
        <GallerySwatch label="ZivoLogo">
          <ZivoLogo height={38} />
        </GallerySwatch>
      </Gallery>

      <Gallery title="Inputs">
        <GallerySwatch label="AppTextField">
          <AppTextField
            label="Email"
            hint="you@example.com"
            value={fieldText}
            onChangeText={setFieldText}
            prefixIcon="email"
          />
        </GallerySwatch>
        <GallerySwatch label="AppSearchBar (editable)">
          <AppSearchBar hintText="Search restaurants" value={searchText} onChangeText={setSearchText} />
        </GallerySwatch>
        <GallerySwatch label="AppSearchBar (tap to open)">
          <AppSearchBar hintText="Search" onPress={() => {}} />
        </GallerySwatch>
      </Gallery>

      <Gallery title="Feedback">
        <GallerySwatch label="CartSnackbar">
          <View className="relative h-x12 overflow-hidden rounded-lg border border-border">
            <CartSnackbar message="Added to cart" />
          </View>
        </GallerySwatch>
      </Gallery>
    </ScrollView>
  );
}

function Gallery({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View className="gap-x4">
      <Text className="text-sectionTitle font-outfitSemiBold text-text">{title}</Text>
      <View className="gap-x5">{children}</View>
    </View>
  );
}

function GallerySwatch({ label, children }: { label: string; children: ReactNode }) {
  return (
    <View className="gap-x2">
      <Text className="text-sectionLabel font-outfitBold text-textMuted">{label}</Text>
      {children}
    </View>
  );
}
