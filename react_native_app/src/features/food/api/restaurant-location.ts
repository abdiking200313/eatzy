/**
 * Ports `RestaurantLocation` (`flutter_app/lib/services/food/models/
 * food_models.dart`) and `SupabaseRestaurantLocationRepository.
 * fetchLocations` (`flutter_app/lib/services/food/data/food_repository.dart`)
 * -- issue #383. Neither file is listed in the issue, but
 * `RestaurantScreen`/`RestaurantHeaderSection` read a restaurant's physical
 * locations through them, so they are ported here alongside the screen.
 * Only the fields the restaurant screen uses are kept beyond the required
 * ones; the coordinate/mapcode fields are carried for parity with the Dart
 * model.
 */
import { supabase } from '@/platform/supabase/client';

export interface RestaurantLocation {
  id: string;
  restaurantId: string;
  storeName: string;
  phoneNumber: string | null;
  latitude: number | null;
  longitude: number | null;
  mapcode: string | null;
  mapcodeTerritory: string | null;
}

export interface RestaurantLocationRow {
  id?: unknown;
  restaurant_id?: unknown;
  store_name?: unknown;
  phonenumber?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  mapcode?: unknown;
  mapcode_territory?: unknown;
}

function requiredString(row: RestaurantLocationRow, key: keyof RestaurantLocationRow): string {
  const value = row[key] == null ? '' : String(row[key]).trim();
  if (!value) {
    throw new Error(`Missing required food field: ${key}`);
  }
  return value;
}

function optionalString(row: RestaurantLocationRow, key: keyof RestaurantLocationRow): string | null {
  const value = row[key] == null ? '' : String(row[key]).trim();
  return value ? value : null;
}

function optionalNumber(row: RestaurantLocationRow, key: keyof RestaurantLocationRow): number | null {
  const value = row[key];
  if (value == null) return null;
  const parsed = typeof value === 'number' ? value : Number(String(value).trim());
  return Number.isFinite(parsed) ? parsed : null;
}

/** Mirrors `RestaurantLocation.fromMap` -- throws on a missing `id`/`restaurant_id`/`store_name`. */
export function restaurantLocationFromRow(row: RestaurantLocationRow): RestaurantLocation {
  return {
    id: requiredString(row, 'id'),
    restaurantId: requiredString(row, 'restaurant_id'),
    storeName: requiredString(row, 'store_name'),
    phoneNumber: optionalString(row, 'phonenumber'),
    latitude: optionalNumber(row, 'latitude'),
    longitude: optionalNumber(row, 'longitude'),
    mapcode: optionalString(row, 'mapcode'),
    mapcodeTerritory: optionalString(row, 'mapcode_territory'),
  };
}

/** The slice of `supabase` {@link fetchRestaurantLocations} depends on. */
export interface RestaurantLocationSource {
  from(table: 'restaurant_locations'): {
    select(columns: string): {
      eq(
        column: string,
        value: string,
      ): {
        order(column: string): PromiseLike<{ data: RestaurantLocationRow[] | null; error: { message: string } | null }>;
      };
    };
  };
}

/** Mirrors `SupabaseRestaurantLocationRepository.fetchLocations`. */
export async function fetchRestaurantLocations(
  restaurantId: string,
  client: RestaurantLocationSource = supabase as unknown as RestaurantLocationSource,
): Promise<RestaurantLocation[]> {
  if (!restaurantId.trim()) {
    throw new Error('A restaurant ID is required.');
  }
  const { data, error } = await client
    .from('restaurant_locations')
    .select('id, restaurant_id, store_name, phonenumber, latitude, longitude, mapcode, mapcode_territory')
    .eq('restaurant_id', restaurantId)
    .order('store_name');
  if (error) throw error;
  return (data ?? []).map(restaurantLocationFromRow);
}
