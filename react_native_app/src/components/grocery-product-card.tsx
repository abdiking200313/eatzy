import { Text, View } from 'react-native';

import { AddToCartButton } from '@/components/add-to-cart-button';
import { OutlinedCard } from '@/components/outlined-card';
import { PhotoThumbnail } from '@/components/photo-thumbnail';
import { StatusPill } from '@/components/status-pill';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { formatCents } from '@/platform/money/format';
import { isGroceryProductAvailable, type GroceryProduct, type GroceryStockState } from '@/stores/grocery-cart-store';
import { radius, rawColors, spacing } from '@/theme/tokens';

export type GroceryProductCardProps = {
  product: GroceryProduct;
  onAdd: () => void;
  /** Opens the product's details page. */
  onPress?: () => void;
  /** See `useServiceTheme`'s `slug` param -- Fresh Meat/Electronics tint the fallback tile with their own accent. */
  slug?: string;
};

const THUMBNAIL_SIZE = 60;

/** Mirrors the Dart `stockLabel` switch. */
export function groceryStockLabel(stockState: GroceryStockState): string {
  switch (stockState) {
    case 'inStock':
      return 'In stock';
    case 'lowStock':
      return 'Low stock';
    case 'outOfStock':
      return 'Out of stock';
  }
}

/** Ports `GroceryProduct.unitLabel`: `"per kg"` for weighed products, `"each"` otherwise. */
export function groceryUnitLabel(product: GroceryProduct): string {
  return product.pricingUnit === 'kilogram' ? 'per kg' : 'each';
}

/**
 * Ports flutter_app/lib/services/grocery/presentation/widgets/
 * grocery_product_card.dart's `GroceryProductCard`: one product row inside
 * a store's scoped catalog -- photo (or emoji fallback tile), name,
 * description, "price unit" line, a stock pill, and an inline add button
 * (disabled with the stock label as its tooltip when unavailable).
 *
 * White card only (dimmed to neutral stone for the unavailable state); the
 * per-service accent is confined to the photo's fallback tile -- same rule
 * as the Dart source.
 */
export function GroceryProductCard({ product, onAdd, onPress, slug }: GroceryProductCardProps) {
  const colors = useSemanticColors();
  const palette = useServiceTheme('grocery', slug);
  const isAvailable = isGroceryProductAvailable(product);
  const stockLabel = groceryStockLabel(product.stockState);
  const pill = stockPillColors(product.stockState, colors);

  return (
    <OutlinedCard
      backgroundColor={isAvailable ? colors.card : rawColors.stone100}
      borderColor={isAvailable ? colors.border : rawColors.stone300}
      onPress={onPress}
      testID={`grocery-product-card-${product.id}`}
      // Same reason as MenuItemCard: the nested add button isn't separately
      // focusable on iOS inside a pressable card (issue #416).
      accessibilityActions={isAvailable ? [{ name: 'addToCart', label: `Add ${product.name}` }] : undefined}
      onAccessibilityAction={(event) => {
        if (event.nativeEvent.actionName === 'addToCart' && isAvailable) onAdd();
      }}>
      <View className="flex-row items-start">
        <PhotoThumbnail
          imageUrl={product.imageUrl}
          size={THUMBNAIL_SIZE}
          fallback={
            <View
              style={{
                width: THUMBNAIL_SIZE,
                height: THUMBNAIL_SIZE,
                borderRadius: radius.lg,
                backgroundColor: isAvailable ? palette.accent : rawColors.stone300,
              }}
              className="items-center justify-center">
              <Text style={{ fontSize: 28 }}>{product.icon}</Text>
            </View>
          }
        />
        <View style={{ width: spacing.x3_5 }} />
        <View style={{ flex: 1 }}>
          <Text className="text-fontBoldBase font-outfitSemiBold text-text">{product.name}</Text>
          <View style={{ height: 3 }} />
          <Text className="text-textSm font-outfitRegular text-text">{product.description}</Text>
          <View style={{ height: spacing.x2 }} />
          <Text className="text-fontBoldSm font-outfitSemiBold text-text">
            {`${formatCents(product.unitPrice)} ${groceryUnitLabel(product)}`}
          </Text>
          <View style={{ height: spacing.x2 }} />
          <StatusPill label={stockLabel} backgroundColor={pill.bg} foregroundColor={pill.fg} />
        </View>
        <AddToCartButton tooltip={isAvailable ? `Add ${product.name}` : stockLabel} onPress={isAvailable ? onAdd : null} />
      </View>
    </OutlinedCard>
  );
}

/** Mirrors the Dart `stockPillColors` switch. `TwColors.tertiary.withOpacityValue(0.14)` becomes an 8-digit hex (0.14 * 255 ~= 0x24). */
function stockPillColors(
  stockState: GroceryStockState,
  colors: ReturnType<typeof useSemanticColors>,
): { bg: string; fg: string } {
  switch (stockState) {
    case 'inStock':
      return { bg: `${colors.tertiary}24`, fg: '#0F7A54' };
    case 'lowStock':
      // `Colors.orange.shade800`.
      return { bg: '#FFF1D6', fg: '#EF6C00' };
    case 'outOfStock':
      return { bg: colors.errorSoft, fg: colors.error };
  }
}
