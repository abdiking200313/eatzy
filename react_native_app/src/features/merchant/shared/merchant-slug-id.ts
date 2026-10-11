/**
 * Ports `flutter_app/lib/features/merchant/shared/merchant_slug_id.dart`
 * (issue #407 / P9-02): a client-side `text` primary key for a table whose
 * `id` column has no server-side default (`grocery_stores`,
 * `pharmacy_stores`, `grocery_products`, `pharmacy_products`), unlike
 * `restaurants`/`menu_items`'s server-generated `uuid`.
 *
 * A readable slug from `seed` plus a short random suffix so two merchants
 * naming a store/item the same thing don't collide.
 */
export function generateMerchantSlugId(seed: string, random: () => number = Math.random): string {
  const base = seed
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  const suffix = Math.floor(random() * 0xffffff).toString(36);
  const prefix = base.length === 0 ? 'item' : base;
  return `${prefix}-${suffix}`;
}
