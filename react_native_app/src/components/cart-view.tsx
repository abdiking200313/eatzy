import { MaterialIcons } from '@expo/vector-icons';
import { Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppScaffold } from './app-scaffold';
import { checkoutLineDisplayValue, CheckoutEmptyState, FeeSummaryRow, type CheckoutLine } from './checkout-view';
import { GradientActionButton } from './gradient-action-button';
import { LoadingState } from './loading-state';
import { OutlinedCard } from './outlined-card';
import { PhotoThumbnail } from './photo-thumbnail';
import { ServiceIconChip } from './service-icon-chip';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { formatCents } from '@/platform/money/format';
import type { ServiceId } from '@/theme/service-theme';
import { radius, spacing } from '@/theme/tokens';

/**
 * Ports flutter_app/lib/widgets/cart_view.dart's `CartLine`: one row of a
 * `CartView`. `total`/`unitPrice` are integer cents.
 */
export type CartLine = {
  /** Stable id, used in this row's testIDs (`increase-cart-item-<id>`, ...), mirroring the Dart `Key`s. */
  id: string;
  name: string;
  total: number;
  /** "2", or "1.5 kg" for weighed grocery products. */
  quantityLabel: string;
  /** Shown as "$X each" when set. */
  unitPrice?: number;
  imageUrl?: string | null;
  /** `null`/`undefined` disables the button (e.g. at the stock ceiling). */
  onDecrease?: (() => void) | null;
  onIncrease?: (() => void) | null;
  onRemove: () => void;
};

export const CART_THUMBNAIL_SIZE = 76;

export type CartThumbnailProps = {
  imageUrl?: string | null;
  /** Shown when there is no photo (or it fails to load). */
  fallbackIcon: keyof typeof MaterialIcons.glyphMap;
  /** Which service's accent palette themes the fallback tile -- see `useServiceTheme`. */
  service?: ServiceId;
  slug?: string;
};

/**
 * Ports flutter_app/lib/widgets/cart_view.dart's `CartThumbnail`: a 76×76
 * product photo, or a soft-tinted `fallbackIcon` tile when there is no
 * photo (or it fails to load).
 */
export function CartThumbnail({ imageUrl, fallbackIcon, service = 'unknown', slug }: CartThumbnailProps) {
  const palette = useServiceTheme(service, slug);
  return (
    <PhotoThumbnail
      imageUrl={imageUrl}
      size={CART_THUMBNAIL_SIZE}
      fallback={
        <ServiceIconChip
          icon={fallbackIcon}
          background={palette.soft}
          foreground={palette.accent}
          size={CART_THUMBNAIL_SIZE}
          iconSize={32}
          borderRadius={radius.tile}
        />
      }
    />
  );
}

function QuantityButton({
  testID,
  accessibilityLabel,
  icon,
  onPress,
}: {
  testID?: string;
  accessibilityLabel: string;
  icon: 'remove' | 'add';
  onPress?: (() => void) | null;
}) {
  const colors = useSemanticColors();
  const disabled = !onPress;
  return (
    <Pressable
      testID={testID}
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

function CartLineRow({
  line,
  fallbackIcon,
  service,
  slug,
}: {
  line: CartLine;
  fallbackIcon: keyof typeof MaterialIcons.glyphMap;
  service: ServiceId;
  slug?: string;
}) {
  const colors = useSemanticColors();
  return (
    <View className="flex-row items-start">
      <CartThumbnail imageUrl={line.imageUrl} fallbackIcon={fallbackIcon} service={service} slug={slug} />
      <View style={{ width: spacing.x3_5 }} />
      <View style={{ flex: 1 }}>
        <View className="flex-row items-start">
          <Text style={{ flex: 1 }} numberOfLines={2} className="text-fontBoldBase font-outfitSemiBold text-text">
            {line.name}
          </Text>
          <Pressable
            testID={`remove-cart-item-${line.id}`}
            accessibilityRole="button"
            accessibilityLabel={`Remove ${line.name}`}
            onPress={line.onRemove}
            style={{ width: 44, height: 44 }}
            className="items-center justify-center">
            <MaterialIcons name="close" size={20} color={colors.textMuted} />
          </Pressable>
        </View>
        <View style={{ height: spacing.x2 }} />
        <Text className="text-fontBoldSm font-outfitSemiBold text-primary">{formatCents(line.total)}</Text>
        <View style={{ height: spacing.x3_5 }} />
        {/* Flex-wrap rather than a plain row so the "$X each" note drops to
            its own line instead of overflowing on a narrow screen with
            enlarged text, mirroring the Dart `Wrap`. */}
        <View
          style={{ flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', columnGap: spacing.x3, rowGap: spacing.x1 }}>
          <View className="flex-row items-center">
            <QuantityButton
              testID={`decrease-cart-item-${line.id}`}
              accessibilityLabel={`Decrease ${line.name}`}
              icon="remove"
              onPress={line.onDecrease}
            />
            <View style={{ minWidth: 28 }}>
              <Text className="text-center text-fontBoldSm font-outfitSemiBold text-text">{line.quantityLabel}</Text>
            </View>
            <QuantityButton
              testID={`increase-cart-item-${line.id}`}
              accessibilityLabel={`Increase ${line.name}`}
              icon="add"
              onPress={line.onIncrease}
            />
          </View>
          {line.unitPrice != null && (
            <Text className="text-textXs font-outfitMedium text-textMuted">{`${formatCents(line.unitPrice)} each`}</Text>
          )}
        </View>
      </View>
    </View>
  );
}

function CartLinesCard({
  lines,
  fallbackIcon,
  service,
  slug,
}: {
  lines: CartLine[];
  fallbackIcon: keyof typeof MaterialIcons.glyphMap;
  service: ServiceId;
  slug?: string;
}) {
  const colors = useSemanticColors();
  return (
    <OutlinedCard borderRadius={radius.card} padding={0}>
      <View style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x1 }}>
        {lines.map((line, index) => (
          <View key={line.id}>
            <View style={{ paddingVertical: spacing.x3 }}>
              <CartLineRow line={line} fallbackIcon={fallbackIcon} service={service} slug={slug} />
            </View>
            {index !== lines.length - 1 && (
              <View style={{ height: 1, backgroundColor: colors.border, marginVertical: spacing.x2 }} />
            )}
          </View>
        ))}
      </View>
    </OutlinedCard>
  );
}

function CartTotalsCard({ feeLines, total }: { feeLines: CheckoutLine[]; total: number | null }) {
  const colors = useSemanticColors();
  return (
    <OutlinedCard borderRadius={radius.card}>
      {feeLines.map((line, index) => (
        <View key={`${index}-${line.label}`} style={{ marginBottom: spacing.x2_5 }}>
          <FeeSummaryRow label={line.label} value={checkoutLineDisplayValue(line)} />
        </View>
      ))}
      <View style={{ height: 1, backgroundColor: colors.border, marginVertical: spacing.x1, marginHorizontal: spacing.x1 }} />
      <FeeSummaryRow label="Total" value={total == null ? 'Calculated at checkout' : formatCents(total)} isBold />
    </OutlinedCard>
  );
}

export type CartViewProps = {
  title?: string;
  showBackButton?: boolean;
  isLoading?: boolean;
  isEmpty: boolean;
  emptyMessage: string;
  browseLabel: string;
  onBrowse: () => void;
  lines: CartLine[];
  /** Subtotal, tax, delivery fee -- whatever this vertical charges. */
  feeLines: CheckoutLine[];
  /**
   * `null` when any fee/tax line is still `isPending` (pricing hasn't
   * loaded yet): shown as "Calculated at checkout" instead of a
   * fabricated number. Continuing to checkout is never blocked on this.
   */
  total: number | null;
  onCheckout: () => void;
  /** Shown in a line's thumbnail when it has no photo. */
  fallbackIcon: keyof typeof MaterialIcons.glyphMap;
  /** The store the whole cart belongs to, shown above the lines. */
  storeName?: string;
  /** Optional one-line note under the store name (e.g. pharmacy's OTC note). */
  notice?: string;
  /** When set, a "Clear" action (with a confirmation) empties the cart. */
  onClear?: () => void;
  /** Which service's accent palette themes each line's thumbnail -- see `useServiceTheme`. */
  service?: ServiceId;
  slug?: string;
};

/**
 * Ports flutter_app/lib/widgets/cart_view.dart's `CartView`: the cart
 * screen shared by food, grocery (incl. Fresh Meat and Electronics) and
 * pharmacy -- one card of lines with quantity steppers, a totals card, and
 * a sticky "Continue to checkout" button.
 */
export function CartView({
  title = 'Cart',
  showBackButton = true,
  isLoading = false,
  isEmpty,
  emptyMessage,
  browseLabel,
  onBrowse,
  lines,
  feeLines,
  total,
  onCheckout,
  fallbackIcon,
  storeName,
  notice,
  onClear,
  service = 'unknown',
  slug,
}: CartViewProps) {
  const colors = useSemanticColors();
  const showCart = !isLoading && !isEmpty;

  const confirmClear = () => {
    Alert.alert('Clear your cart?', 'This will remove every item from your cart.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Clear cart', style: 'destructive', onPress: () => onClear?.() },
    ]);
  };

  return (
    <AppScaffold
      title={title}
      showBackButton={showBackButton}
      actions={
        showCart && onClear ? (
          <Pressable
            accessibilityRole="button"
            onPress={confirmClear}
            style={{ paddingHorizontal: spacing.x2 }}
            className="active:opacity-70">
            <Text className="text-button font-outfitSemiBold text-primary">Clear</Text>
          </Pressable>
        ) : undefined
      }
      bottomBar={
        showCart ? (
          <SafeAreaView
            edges={['bottom']}
            style={{ paddingHorizontal: spacing.x4, paddingTop: spacing.x4, paddingBottom: spacing.x3 }}>
            <GradientActionButton
              testID="cart-checkout"
              label={total == null ? 'Continue to checkout' : `Continue to checkout • ${formatCents(total)}`}
              onPress={onCheckout}
              borderRadius={radius.media}
              paddingVertical={spacing.x4}
              paddingHorizontal={spacing.x5}
              icon={<MaterialIcons name="arrow-forward" size={20} color={colors.onPrimary} />}
            />
          </SafeAreaView>
        ) : undefined
      }>
      {isLoading ? (
        <LoadingState />
      ) : isEmpty ? (
        <CheckoutEmptyState message={emptyMessage} browseLabel={browseLabel} onBrowse={onBrowse} />
      ) : (
        <ScrollView
          contentContainerStyle={{
            paddingHorizontal: spacing.screenX,
            paddingTop: spacing.x2,
            paddingBottom: spacing.x6,
          }}>
          {storeName != null && (
            <>
              <Text className="text-textXl font-outfitBold text-text">{storeName}</Text>
              <View style={{ height: spacing.x1 }} />
            </>
          )}
          {notice != null && (
            <>
              <Text className="text-textSm font-outfitRegular text-text">{notice}</Text>
              <View style={{ height: spacing.x1 }} />
            </>
          )}
          <View style={{ height: spacing.x3 }} />
          <CartLinesCard lines={lines} fallbackIcon={fallbackIcon} service={service} slug={slug} />
          <View style={{ height: spacing.x5 }} />
          <CartTotalsCard feeLines={feeLines} total={total} />
        </ScrollView>
      )}
    </AppScaffold>
  );
}
