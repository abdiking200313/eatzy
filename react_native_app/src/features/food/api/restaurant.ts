/**
 * Ports `flutter_app/lib/services/food/models/restaurant.dart`'s
 * `Restaurant` (issue #382): one restaurant as shown in the food home
 * screen's listing.
 */
export interface Restaurant {
  id: string;
  name: string;
  description: string;
  logoUrl: string;
}

/** A raw `restaurants` row, as selected by `fetchRestaurants` below. */
export interface RestaurantRow {
  id: string;
  name: string | null;
  description: string | null;
  logo_url: string | null;
}

/** Mirrors `Restaurant.fromMap`'s column names and `?? 'Unknown'`/`?? ''` fallbacks. */
export function restaurantFromRow(row: RestaurantRow): Restaurant {
  return {
    id: String(row.id),
    name: row.name ?? 'Unknown',
    description: row.description ?? '',
    logoUrl: row.logo_url ?? '',
  };
}
