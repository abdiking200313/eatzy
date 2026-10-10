import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { router } from 'expo-router';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { Pressable, ScrollView, Text, useWindowDimensions, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { GradientActionButton } from './gradient-action-button';
import { StatusPill } from './status-pill';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { useServiceTheme } from '@/hooks/use-service-theme';
import type { ServiceId } from '@/theme/service-theme';
import { radius, spacing } from '@/theme/tokens';

// Mirrors `store-list-card.tsx`'s own private `withAlpha` helper (there is
// no shared hex/alpha utility in this app yet) -- stands in for the Dart
// `Color.withOpacityValue` call on the in-stock pill's tinted background.
function withAlpha(hex: string, alpha: number): string {
  const normalized = hex.replace('#', '');
  const value =
    normalized.length === 3
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

function StepperButton({
  accessibilityLabel,
  icon,
  onPress,
}: {
  accessibilityLabel: string;
  icon: 'remove' | 'add';
  onPress?: (() => void) | null;
}) {
  const colors = useSemanticColors();
  const disabled = !onPress;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress ?? undefined}
      style={{ width: 36, height: 36, borderRadius: radius.chip, borderWidth: 1, borderColor: colors.border }}
      className={`items-center justify-center ${disabled ? '' : 'active:opacity-70'}`}>
      <MaterialIcons name={icon} size={18} color={disabled ? colors.textMuted : colors.text} />
    </Pressable>
  );
}

export type ProductDetailsViewProps = {
  imageUrl?: string | null;
  /** Shown in the hero when there's no photo (or it fails to load). */
  fallback: ReactNode;
  name: string;
  priceLabel: string;
  /**
   * The stock pill's label, e.g. "In stock" or "Only 2 left". Omit
   * entirely to hide the pill (food items have no stock concept).
   */
  stockLabel?: string;
  isInStock?: boolean;
  description: string;
  /** Small label above the name, e.g. the pharmacy category. */
  eyebrow?: string;
  /** Short extra lines, e.g. "Sold by weight, in 0.5 kg steps". */
  facts?: string[];
  /**
   * How many quantity steps can still be added (stock minus what's
   * already in the cart). Below 1, Add to cart is disabled and shows
   * `unavailableLabel`.
   */
  maxSteps: number;
  /** Renders a step count for the picker, e.g. "3" or "1.5 kg". */
  quantityLabel: (steps: number) => string;
  /**
   * Called with the chosen number of steps after this page has navigated
   * back, so any follow-up dialog/snackbar shows on the product list
   * underneath -- mirrors the Dart widget popping its `Navigator` route
   * before calling this.
   */
  onAddToCart: (steps: number) => void;
  unavailableLabel?: string;
  /** Which service's accent palette themes the price label -- see `useServiceTheme`. */
  service?: ServiceId;
  slug?: string;
};

/**
 * Ports flutter_app/lib/widgets/product_details_view.dart's
 * `ProductDetailsView`: the shared full-screen "more info" page for a
 * single food, grocery, or pharmacy item -- a photo hero, name, price, an
 * optional stock pill, description, a quantity picker, and Add to cart.
 *
 * The Dart widget is a `StatefulWidget` that owns its own `_steps`
 * quantity-picker state; this ports that as local `useState`, matching the
 * driving issue's instruction not to lift it to a parent or a store.
 *
 * Deviation: Flutter's `CustomScrollView` + pinned `SliverAppBar` +
 * `FlexibleSpaceBar` collapses the hero into a persistent top bar as the
 * page scrolls. There is no direct RN equivalent without an extra
 * scroll-animation library, which is out of scope for this port -- this
 * renders a plain static hero followed by a scrolling body instead, with
 * its own back button overlaid on the hero (not a collapsing/sticky bar).
 */
export function ProductDetailsView({
  imageUrl,
  fallback,
  name,
  priceLabel,
  stockLabel,
  isInStock = true,
  description,
  eyebrow,
  facts = [],
  maxSteps,
  quantityLabel,
  onAddToCart,
  unavailableLabel = 'Out of stock',
  service = 'unknown',
  slug,
}: ProductDetailsViewProps) {
  const colors = useSemanticColors();
  const palette = useServiceTheme(service, slug);
  const { width } = useWindowDimensions();
  const [steps, setSteps] = useState(1);

  const canAdd = maxSteps >= 1;
  // Product photos are uploaded square, so a square-ish hero shows them
  // whole on phones while staying reasonable on wide screens.
  const heroHeight = Math.min(Math.max(width, 0), 360);
  const url = imageUrl?.trim() ?? '';

  const handleAdd = () => {
    const chosenSteps = steps;
    router.back();
    onAddToCart(chosenSteps);
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.card }}>
      <ScrollView>
        <View style={{ height: heroHeight, backgroundColor: colors.card }} className="items-center justify-center">
          {url ? (
            <Image
              source={{ uri: url }}
              style={{ width: '100%', height: '100%' }}
              contentFit="cover"
              cachePolicy="memory-disk"
            />
          ) : (
            fallback
          )}
        </View>
        <View style={{ padding: spacing.x5 }}>
          {eyebrow != null && (
            <>
              <Text className="text-link font-outfitSemiBold text-primary">{eyebrow}</Text>
              <View style={{ height: spacing.x2 }} />
            </>
          )}
          <Text className="text-text2xl font-outfitBold text-text">{name}</Text>
          <View style={{ height: spacing.x2 }} />
          <Text style={{ color: palette.accent }} className="text-fontBoldBase font-outfitSemiBold">
            {priceLabel}
          </Text>
          {stockLabel != null && (
            <>
              <View style={{ height: spacing.x3 }} />
              <StatusPill
                label={stockLabel}
                backgroundColor={isInStock ? withAlpha(colors.tertiary, 0.14) : colors.errorSoft}
                foregroundColor={isInStock ? '#0F7A54' : colors.error}
              />
            </>
          )}
          {description.trim().length > 0 && (
            <>
              <View style={{ height: spacing.x4 }} />
              <Text className="text-textSm font-outfitRegular text-text">{description}</Text>
            </>
          )}
          {facts.map((fact, index) => (
            <View key={index} style={{ marginTop: spacing.x2 }} className="flex-row items-start">
              <MaterialIcons name="info-outline" size={16} color={colors.textMuted} />
              <Text
                style={{ marginLeft: spacing.x2, flex: 1 }}
                className="text-textSm font-outfitRegular text-textMuted">
                {fact}
              </Text>
            </View>
          ))}
        </View>
      </ScrollView>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Back"
        onPress={() => router.back()}
        style={{ position: 'absolute', top: spacing.x2, left: spacing.x2, width: 40, height: 40, backgroundColor: colors.card, borderRadius: radius.full }}
        className="items-center justify-center active:opacity-70">
        <MaterialIcons name="arrow-back" size={22} color={colors.text} />
      </Pressable>
      <SafeAreaView
        edges={['bottom']}
        style={{ paddingHorizontal: spacing.x5, paddingTop: spacing.x3, paddingBottom: spacing.x3 }}
        className="flex-row items-center">
        {canAdd && (
          <>
            <StepperButton
              accessibilityLabel="Decrease quantity"
              icon="remove"
              onPress={steps > 1 ? () => setSteps((value) => value - 1) : null}
            />
            <View style={{ minWidth: 28 }}>
              <Text className="text-center text-fontBoldBase font-outfitSemiBold text-text">
                {quantityLabel(steps)}
              </Text>
            </View>
            <StepperButton
              accessibilityLabel="Increase quantity"
              icon="add"
              onPress={steps < maxSteps ? () => setSteps((value) => value + 1) : null}
            />
            <View style={{ width: spacing.x3 }} />
          </>
        )}
        <View style={{ flex: 1 }}>
          <GradientActionButton
            label={canAdd ? 'Add to cart' : unavailableLabel}
            onPress={canAdd ? handleAdd : null}
            icon={<MaterialIcons name="shopping-cart" size={18} color={colors.onPrimary} />}
          />
        </View>
      </SafeAreaView>
    </View>
  );
}
