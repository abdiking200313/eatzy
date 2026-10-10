/**
 * Ports the grocery checkout models and data access (issue #392 / P7-04):
 *
 * - `GroceryDeliverySlot` (+ `fromMap`), `GrocerySubstitutionPreference`
 *   (+ its `label`/`description` extension), `GroceryOrderLineInput.toRpcMap`
 *   and `GroceryOrderRequest.toRpcParams` from
 *   `flutter_app/lib/services/grocery/models/grocery_models.dart`;
 * - `SupabaseGroceryCatalogRepository.fetchDeliverySlots` and
 *   `SupabaseGroceryOrderRepository.placeOrder` from
 *   `flutter_app/lib/services/grocery/data/grocery_repository.dart`.
 *
 * The request carries only ids and quantities -- never a price.
 * `place_grocery_order` prices every line from the live catalog, reads the
 * delivery fee from `service_pricing`, re-checks that the slot's delivery
 * window has not already passed (issue #82), and returns the authoritative
 * totals in integer cents, parsed here into a shared `PlacedOrder`.
 *
 * Same free-function + injectable narrow `*Source` convention as
 * `features/food/api/food-order-repository.ts`.
 */
import { deliveryDetailsToRpcParams, EMPTY_DELIVERY_DETAILS, type DeliveryDetails } from '@/platform/orders/delivery-details';
import { parsePlacedOrder, type PlacedOrder } from '@/platform/orders/placed-order';
import { supabase } from '@/platform/supabase/client';

// --- Delivery slots -----------------------------------------------------------

/** Ports `GroceryDeliverySlot`. */
export interface GroceryDeliverySlot {
  id: string;
  /** e.g. "Today". */
  label: string;
  /** e.g. "2:00 PM – 4:00 PM". */
  detail: string;
  storeId?: string | null;
}

export interface GroceryDeliverySlotRow {
  id: unknown;
  store_id: unknown;
  label: unknown;
  detail: unknown;
}

function requiredString(row: Record<string, unknown>, key: string): string {
  const value = row[key] == null ? '' : String(row[key]).trim();
  if (value.length === 0) {
    throw new Error(`Missing required grocery field: ${key}`);
  }
  return value;
}

/** Ports `GroceryDeliverySlot.fromMap`, including its required-field validation. */
export function groceryDeliverySlotFromRow(row: GroceryDeliverySlotRow): GroceryDeliverySlot {
  const map = row as unknown as Record<string, unknown>;
  return {
    id: requiredString(map, 'id'),
    label: requiredString(map, 'label'),
    detail: requiredString(map, 'detail'),
    storeId: requiredString(map, 'store_id'),
  };
}

interface SlotFilterChain extends PromiseLike<{ data: GroceryDeliverySlotRow[] | null; error: unknown }> {
  select(columns: string): SlotFilterChain;
  eq(column: string, value: unknown): SlotFilterChain;
  order(column: string): SlotFilterChain;
}

/** The slice of `supabase` {@link fetchGroceryDeliverySlots} depends on. */
export interface GroceryDeliverySlotSource {
  from(table: 'grocery_delivery_slots_available'): SlotFilterChain;
}

/**
 * Ports `SupabaseGroceryCatalogRepository.fetchDeliverySlots`. Reads the
 * `grocery_delivery_slots_available` view, not the base table: the view
 * already excludes a slot whose delivery window has elapsed (and, via RLS
 * with `security_invoker`, an inactive slot or one at an inactive store).
 */
export async function fetchGroceryDeliverySlots(
  storeId: string,
  client: GroceryDeliverySlotSource = supabase as unknown as GroceryDeliverySlotSource,
): Promise<GroceryDeliverySlot[]> {
  if (storeId.trim().length === 0) {
    throw new Error('A grocery store ID is required.');
  }
  const { data, error } = await client
    .from('grocery_delivery_slots_available')
    .select('id, store_id, label, detail')
    .eq('store_id', storeId)
    .order('sort_order');
  if (error) throw error;
  return (data ?? []).map(groceryDeliverySlotFromRow);
}

// --- Substitution preference ---------------------------------------------------

/** Ports `GrocerySubstitutionPreference`. */
export type GrocerySubstitutionPreference = 'bestMatch' | 'contactMe' | 'noSubstitutions';

/** Mirrors `GrocerySubstitutionPreference.values` (declaration order). */
export const GROCERY_SUBSTITUTION_PREFERENCES: readonly GrocerySubstitutionPreference[] = [
  'bestMatch',
  'contactMe',
  'noSubstitutions',
];

/** Ports `GrocerySubstitutionPreferenceLabel.label`. */
export function grocerySubstitutionLabel(preference: GrocerySubstitutionPreference): string {
  switch (preference) {
    case 'bestMatch':
      return 'Choose the best match';
    case 'contactMe':
      return 'Contact me first';
    case 'noSubstitutions':
      return 'No substitutions';
  }
}

/** Ports `GrocerySubstitutionPreferenceLabel.description`. */
export function grocerySubstitutionDescription(preference: GrocerySubstitutionPreference): string {
  switch (preference) {
    case 'bestMatch':
      return 'Replace unavailable items with a similar product.';
    case 'contactMe':
      return 'Ask before replacing an unavailable item.';
    case 'noSubstitutions':
      return 'Refund any item that becomes unavailable.';
  }
}

/** The `p_substitution_preference` value `place_grocery_order` expects. */
export function grocerySubstitutionToDb(preference: GrocerySubstitutionPreference): string {
  switch (preference) {
    case 'bestMatch':
      return 'best_match';
    case 'contactMe':
      return 'contact_me';
    case 'noSubstitutions':
      return 'no_substitutions';
  }
}

// --- Order request -----------------------------------------------------------

/** Ports `GroceryOrderLineInput`. `quantity` may be fractional (0.5 kg steps). */
export interface GroceryOrderLineInput {
  productId: string;
  quantity: number;
}

/** Ports `GroceryOrderRequest`. */
export interface GroceryOrderRequest {
  storeId: string;
  deliverySlotId: string;
  substitutionPreference: GrocerySubstitutionPreference;
  items: GroceryOrderLineInput[];
  /** Defaults to an empty delivery note. */
  delivery?: DeliveryDetails;
  /**
   * A client-generated token identifying this checkout attempt.
   * `place_grocery_order` uses it, together with the caller's profile, to
   * return the existing order instead of inserting a duplicate row and
   * decrementing stock again when the same attempt is submitted more than
   * once. `null`/omitted disables that protection.
   */
  idempotencyKey?: string | null;
}

/** The exact `place_grocery_order` argument object -- mirrors `Database['public']['Functions']['place_grocery_order']['Args']`. */
export interface GroceryOrderRpcParams {
  p_store_id: string;
  p_delivery_slot_id: string;
  p_recipient_name: string;
  p_phone: string;
  p_street: string;
  p_district: string;
  p_city: string;
  p_substitution_preference: string;
  p_items: { product_id: string; quantity: number }[];
  p_idempotency_key: string | null;
}

/** Ports `GroceryOrderLineInput.toRpcMap`, including its validation. */
export function groceryOrderLineToRpcMap(line: GroceryOrderLineInput): { product_id: string; quantity: number } {
  if (line.productId.trim().length === 0) {
    throw new Error('A grocery product ID is required.');
  }
  if (!Number.isFinite(line.quantity) || line.quantity <= 0) {
    throw new Error('Grocery quantity must be positive.');
  }
  return { product_id: line.productId, quantity: line.quantity };
}

/** Ports `GroceryOrderRequest.toRpcParams`, including its validation. */
export function groceryOrderRequestToRpcParams(request: GroceryOrderRequest): GroceryOrderRpcParams {
  if (request.storeId.trim().length === 0 || request.deliverySlotId.trim().length === 0) {
    throw new Error('Store and delivery slot are required.');
  }
  if (request.items.length === 0) {
    throw new Error('A grocery order requires at least one item.');
  }
  return {
    p_store_id: request.storeId,
    p_delivery_slot_id: request.deliverySlotId,
    ...deliveryDetailsToRpcParams(request.delivery ?? EMPTY_DELIVERY_DETAILS),
    p_substitution_preference: grocerySubstitutionToDb(request.substitutionPreference),
    p_items: request.items.map(groceryOrderLineToRpcMap),
    p_idempotency_key: request.idempotencyKey ?? null,
  };
}

/** The slice of `supabase` {@link placeGroceryOrder} depends on. */
export interface GroceryOrderSource {
  rpc(name: 'place_grocery_order', params: GroceryOrderRpcParams): PromiseLike<{ data: unknown; error: unknown }>;
}

/**
 * Ports `SupabaseGroceryOrderRepository.placeOrder`: calls
 * `place_grocery_order` and returns the server-computed `PlacedOrder`. A
 * PostgREST error (e.g. the elapsed-slot or missing-contact-details
 * exception) is rethrown as-is for the caller to map.
 */
export async function placeGroceryOrder(
  request: GroceryOrderRequest,
  client: GroceryOrderSource = supabase as unknown as GroceryOrderSource,
): Promise<PlacedOrder> {
  const { data, error } = await client.rpc('place_grocery_order', groceryOrderRequestToRpcParams(request));
  if (error) throw error;
  return parsePlacedOrder(data, 'grocery order');
}
