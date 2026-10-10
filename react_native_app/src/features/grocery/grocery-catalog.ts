/**
 * Pure catalog helpers for the grocery store screen (issue #390 / P7-02).
 *
 * Ports `groupByCategory` and `_GroceryStoreScreenState._visibleProducts`
 * from `flutter_app/lib/services/grocery/presentation/grocery_store_screen.dart`.
 *
 * `flutter_app/lib/services/grocery/presentation/grocery_catalog.dart`'s
 * `GroceryCatalog` itself (a `ChangeNotifier`-side cache of loaded stores,
 * their staleness, and delivery slots) has no 1:1 port: as with
 * `grocery-store-list-screen.tsx` (issue #389), loading is a plain injected
 * loader -- `fetchGroceryStore` in `./api/grocery-repository.ts` is the
 * port of `GroceryCatalog.loadStore` (one store and only its own products),
 * and delivery slots (`loadDeliverySlots`/`defaultGroceryDeliverySlots`)
 * belong to grocery checkout, a later issue.
 */
import type { GroceryProduct } from '@/stores/grocery-cart-store';

export interface GroceryCategorySection {
  name: string;
  products: GroceryProduct[];
}

/** Section name for products with no `grocery_categories` row. */
export const UNCATEGORISED_SECTION_NAME = 'Other';

/**
 * Groups `products` into category sections, like the restaurant menu:
 * sections ordered by `grocery_categories.sort_order` (then name), with
 * uncategorised products last under "Other". Products keep their incoming
 * order (by name, from the repository) within a section. Ports
 * `groupByCategory`.
 */
export function groupByCategory(products: readonly GroceryProduct[]): GroceryCategorySection[] {
  const groups = new Map<string | null, GroceryProduct[]>();
  for (const product of products) {
    const key = product.categoryName ?? null;
    const existing = groups.get(key);
    if (existing) {
      existing.push(product);
    } else {
      groups.set(key, [product]);
    }
  }

  const entries = [...groups.entries()].sort(([aKey, aProducts], [bKey, bProducts]) => {
    if (aKey === null || bKey === null) {
      return (aKey === null ? 1 : 0) - (bKey === null ? 1 : 0);
    }
    const bySortOrder = (aProducts[0].categorySortOrder ?? 0) - (bProducts[0].categorySortOrder ?? 0);
    if (bySortOrder !== 0) return bySortOrder;
    // Dart's `String.compareTo` is a plain code-unit comparison, not a
    // locale-aware one.
    return aKey < bKey ? -1 : aKey > bKey ? 1 : 0;
  });

  return entries.map(([key, sectionProducts]) => ({ name: key ?? UNCATEGORISED_SECTION_NAME, products: sectionProducts }));
}

/** Filters by case-insensitive product-name substring; an empty/blank query returns every product. Ports `_visibleProducts`. */
export function filterProductsByName(products: GroceryProduct[], query: string): GroceryProduct[] {
  const normalized = query.trim().toLowerCase();
  if (normalized.length === 0) return products;
  return products.filter((product) => product.name.toLowerCase().includes(normalized));
}
