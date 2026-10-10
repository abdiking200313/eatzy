/**
 * Ports `flutter_app/lib/services/food/models/restaurant_menu.dart`'s
 * `RestaurantMenu`/`MenuCategory`/`MenuItem` (issue #383): one restaurant's
 * menu, items grouped by category.
 *
 * Dart hand-rolls `toMap`/`fromMap` on these models so its own hand-rolled
 * `QueryCache` can JSON-round-trip them to disk. This app persists its
 * TanStack Query cache generically (`src/platform/query/query-persistence.
 * ts`, issue #347/#372) by `JSON.stringify`-ing whatever `queryFn` resolves
 * to -- and every field below (`string`/`number`/arrays of plain objects) is
 * already JSON-safe, so no equivalent `toMap`/`fromMap` pair is needed here.
 */
import type { Restaurant } from './restaurant';

export type { Restaurant };

export interface MenuItem {
  id: string;
  name: string;
  description: string;
  /**
   * Price in integer cents (smallest currency unit). Convert to decimal
   * dollars only at display time (mirrors `AppMoney.formatCents` -- see
   * `AGENTS.md`'s money-column convention).
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

/** Mirrors `RestaurantMenu.itemCount`'s getter. */
export function restaurantMenuItemCount(menu: RestaurantMenu): number {
  return menu.categories.reduce((count, category) => count + category.items.length, 0);
}

/** A raw `menu_items` row joined to its `item_categories` row, as selected by `fetchMenu` in `restaurant-menu-repository.ts`. */
export interface MenuItemRow {
  id: string;
  name: string | null;
  description: string | null;
  /** May be a number, a numeric string, or missing/null -- see `menuItemFromRow`. */
  price: unknown;
  image_url: string | null;
  categorie_id: string | null;
  /**
   * Postgrest embeds a to-one relation as a single object, but defensively
   * accepted as a one-element array too (some Postgrest configurations
   * return relations as arrays regardless of cardinality).
   */
  item_categories: { id: string; name: string | null } | { id: string; name: string | null }[] | null;
}

/**
 * Thrown by {@link menuItemFromRow} when `price` is missing or unparseable,
 * rather than defaulting to `0`: a menu item silently priced at $0.00 could
 * be added to cart for free client-side even though the server would still
 * charge the real amount, which is worse than not showing the item at all.
 * `fetchMenu` (in `restaurant-menu-repository.ts`) catches this per item and
 * excludes just that item from the menu -- mirrors Dart's `FormatException`
 * + `RestaurantMenuRepository._groupItemsByCategory`'s per-item `catch`.
 */
export class InvalidMenuItemPriceError extends Error {
  constructor(itemId: unknown, rawPrice: unknown) {
    super(`Invalid menu item price for ${itemId}: ${String(rawPrice)}`);
    this.name = 'InvalidMenuItemPriceError';
  }
}

/** Mirrors Dart's `int.tryParse`: only a plain (optionally negative) integer string parses; anything else (e.g. `"4.50"`, `"abc"`, `""`) is rejected rather than silently truncated. */
function tryParseInt(value: string): number | null {
  return /^-?\d+$/.test(value) ? parseInt(value, 10) : null;
}

/** Mirrors `MenuItem.fromMap`'s column names, fallbacks, and price-parsing contract -- see {@link InvalidMenuItemPriceError}. */
export function menuItemFromRow(row: MenuItemRow): MenuItem {
  const rawPrice = row.price;
  const price = typeof rawPrice === 'number' ? Math.round(rawPrice) : tryParseInt(String(rawPrice ?? ''));
  if (price === null || price < 0) {
    throw new InvalidMenuItemPriceError(row.id, rawPrice);
  }

  return {
    id: String(row.id),
    name: row.name ?? 'Unnamed item',
    description: row.description ?? '',
    price,
    imageUrl: row.image_url ?? '',
    categoryId: row.categorie_id != null ? String(row.categorie_id) : 'uncategorized',
  };
}
