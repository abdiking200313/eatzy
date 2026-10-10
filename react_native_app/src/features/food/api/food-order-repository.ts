/**
 * Ports the food order request model and its Supabase repository (issue
 * #387 / P6-06):
 *
 * - `FoodOrderLineInput`/`FoodOrderRequest.toRpcParams` from
 *   `flutter_app/lib/services/food/models/food_models.dart`;
 * - `SupabaseFoodOrderRepository.placeOrder` from
 *   `flutter_app/lib/services/food/data/food_repository.dart`.
 *
 * The request carries only ids and quantities -- never a price. The
 * `place_food_order` RPC (see
 * `supabase/migrations/20260927010000_make_delivery_address_optional.sql`)
 * prices every line from the live `menu_items` catalog, reads delivery
 * fee/tax from `service_pricing`, and returns the authoritative totals in
 * integer cents, parsed here into a shared `PlacedOrder`.
 *
 * Follows the free-function + injectable narrow `*Source` convention of
 * `category-repository.ts` rather than Dart's constructor-injected class.
 */
import { deliveryDetailsToRpcParams, EMPTY_DELIVERY_DETAILS, type DeliveryDetails } from '@/platform/orders/delivery-details';
import { parsePlacedOrder, type PlacedOrder } from '@/platform/orders/placed-order';
import { supabase } from '@/platform/supabase/client';

/** Ports `FoodOrderLineInput`. */
export interface FoodOrderLineInput {
  menuItemId: string;
  quantity: number;
}

/** Ports `FoodOrderRequest`. */
export interface FoodOrderRequest {
  restaurantId: string;
  items: FoodOrderLineInput[];
  /** Defaults to an empty delivery note. */
  delivery?: DeliveryDetails;
  /**
   * A client-generated token identifying this checkout attempt.
   * `place_food_order` uses it, together with the caller's profile, to
   * return the existing order instead of inserting a duplicate when the
   * same attempt is submitted more than once (a double-tap or a retry
   * after a lost response). `null`/omitted disables that protection.
   */
  idempotencyKey?: string | null;
}

/** The exact `place_food_order` argument object -- mirrors `Database['public']['Functions']['place_food_order']['Args']`. */
export interface FoodOrderRpcParams {
  p_restaurant_id: string;
  p_recipient_name: string;
  p_phone: string;
  p_street: string;
  p_district: string;
  p_city: string;
  p_items: { menu_item_id: string; quantity: number }[];
  p_idempotency_key: string | null;
}

/** Ports `FoodOrderLineInput.toRpcMap`, including its validation (Dart's `FormatException` becomes a thrown `Error`). */
export function foodOrderLineToRpcMap(line: FoodOrderLineInput): { menu_item_id: string; quantity: number } {
  if (line.menuItemId.trim().length === 0) {
    throw new Error('A menu item ID is required.');
  }
  if (line.quantity <= 0) {
    throw new Error('Food quantity must be positive.');
  }
  return { menu_item_id: line.menuItemId, quantity: line.quantity };
}

/** Ports `FoodOrderRequest.toRpcParams`, including its validation. */
export function foodOrderRequestToRpcParams(request: FoodOrderRequest): FoodOrderRpcParams {
  if (request.restaurantId.trim().length === 0) {
    throw new Error('A restaurant ID is required.');
  }
  if (request.items.length === 0) {
    throw new Error('A food order requires at least one item.');
  }
  return {
    p_restaurant_id: request.restaurantId,
    ...deliveryDetailsToRpcParams(request.delivery ?? EMPTY_DELIVERY_DETAILS),
    p_items: request.items.map(foodOrderLineToRpcMap),
    p_idempotency_key: request.idempotencyKey ?? null,
  };
}

/**
 * The slice of `supabase` {@link placeFoodOrder} depends on -- structurally
 * satisfied by both the real client and
 * `src/test-utils/fake-supabase-client.ts`.
 */
export interface FoodOrderSource {
  rpc(name: 'place_food_order', params: FoodOrderRpcParams): PromiseLike<{ data: unknown; error: unknown }>;
}

/**
 * Ports `SupabaseFoodOrderRepository.placeOrder`: calls `place_food_order`
 * and returns the server-computed `PlacedOrder`. A PostgREST error is
 * rethrown as-is (supabase-js returns it rather than throwing), so
 * `describeOrderSaveError` can still recognise the missing-contact-details
 * message.
 */
export async function placeFoodOrder(
  request: FoodOrderRequest,
  client: FoodOrderSource = supabase as unknown as FoodOrderSource,
): Promise<PlacedOrder> {
  const { data, error } = await client.rpc('place_food_order', foodOrderRequestToRpcParams(request));
  if (error) throw error;
  return parsePlacedOrder(data, 'food order');
}
