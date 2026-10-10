/**
 * Ports `flutter_app/lib/services/food/models/restaurant_menu.dart`'s
 * `RestaurantMenu`/`MenuCategory`/`MenuItem` (issue #383): one restaurant's
 * menu, grouped by category, as shown on the restaurant screen.
 *
 * The Dart `toMap`/`fromMap` pairs exist only so `QueryCache` can
 * JSON-encode a menu; this app's TanStack Query persister serializes these
 * plain objects as-is (see `use-restaurant-menu.ts`), so they have no
 * counterpart here. Only `MenuItem.fromMap`'s row parsing -- with its
 * "never price an item at $0.00" validation -- is ported, as
 * {@link menuItemFromRow}.
 */
import type { Restaurant } from './restaurant';

export interface MenuItem {
  id: string;
  name: string;
  description: string;
  /**
   * Price in integer cents (smallest currency unit). Convert to decimal
   * dollars only at display time, via `formatCents(price)`.
   */
  price: number;
  imageUrl: string;
  categoryId: string;
}

export interface MenuCategory {
  id: string;
  name: string;
  items: MenuItem[];
}

export interface RestaurantMenu {
  restaurant: Restaurant;
  categories: MenuCategory[];
}

/** A raw `menu_items` row, as selected by `fetchRestaurantMenu`. */
export interface MenuItemRow {
  id: string | number;
  name?: string | null;
  description?: string | null;
  price?: unknown;
  image_url?: string | null;
  categorie_id?: string | number | null;
  item_categories?: { id?: unknown; name?: string | null } | null;
}

/** Thrown by {@link menuItemFromRow} for a missing/unparseable/negative price -- mirrors Dart's `FormatException`. */
export class MenuItemFormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MenuItemFormatError';
  }
}

/** Mirrors `RestaurantMenu.itemCount`. */
export function restaurantMenuItemCount(menu: RestaurantMenu): number {
  return menu.categories.reduce((count, category) => count + category.items.length, 0);
}

/** Mirrors Dart's `int.tryParse`: only a plain (optionally signed) integer string parses. */
function tryParseInt(value: string): number | null {
  return /^[+-]?\d+$/.test(value.trim()) ? parseInt(value.trim(), 10) : null;
}

/**
 * Ports `MenuItem.fromMap`. Throws a {@link MenuItemFormatError} when
 * `price` is missing or unparseable rather than defaulting to `0`: a menu
 * item silently priced at $0.00 could be added to cart for free
 * client-side even though the server would still charge the real amount,
 * which is worse than not showing the item at all. `fetchRestaurantMenu`
 * catches this per item and excludes just that item from the menu.
 */
export function menuItemFromRow(row: MenuItemRow): MenuItem {
  const rawPrice = row.price;
  const price =
    typeof rawPrice === 'number' && Number.isFinite(rawPrice)
      ? Math.round(rawPrice)
      : tryParseInt(rawPrice == null ? '' : String(rawPrice));
  if (price == null || price < 0) {
    throw new MenuItemFormatError(`Invalid menu item price for ${row.id}: ${String(rawPrice)}`);
  }

  return {
    id: String(row.id),
    name: row.name ?? 'Unnamed item',
    description: row.description ?? '',
    price,
    imageUrl: row.image_url ?? '',
    categoryId: row.categorie_id == null ? 'uncategorized' : String(row.categorie_id),
  };
}
