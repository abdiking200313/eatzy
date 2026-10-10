/**
 * Ports the pharmacy order request and data access (issue #395 / P7-07):
 *
 * - `PharmacyOrderLineInput.toRpcMap` and `PharmacyOrderRequest.toRpcParams`
 *   from `flutter_app/lib/services/pharmacy/models/pharmacy_checkout.dart`;
 * - `SupabasePharmacyOrderRepository.placeOrder` from
 *   `flutter_app/lib/services/pharmacy/data/pharmacy_repository.dart`.
 *
 * The request carries only product ids and quantities -- never a price.
 * `place_pharmacy_order` prices every line from the live catalog, reads the
 * delivery fee from `service_pricing`, and returns the authoritative totals
 * in integer cents, parsed here into a shared `PlacedOrder`. Unlike grocery,
 * the request carries no store id (the RPC derives it from the products).
 *
 * Same free-function + injectable narrow `*Source` convention as
 * `features/grocery/api/grocery-order-repository.ts`.
 */
import { deliveryDetailsToRpcParams, EMPTY_DELIVERY_DETAILS, type DeliveryDetails } from '@/platform/orders/delivery-details';
import { parsePlacedOrder, type PlacedOrder } from '@/platform/orders/placed-order';
import { supabase } from '@/platform/supabase/client';

/** Ports `PharmacyOrderLineInput`. */
export interface PharmacyOrderLineInput {
  productId: string;
  quantity: number;
}

/** Ports `PharmacyOrderRequest`. */
export interface PharmacyOrderRequest {
  items: PharmacyOrderLineInput[];
  /** Defaults to an empty delivery note. */
  delivery?: DeliveryDetails;
  /**
   * A client-generated token identifying this checkout attempt.
   * `place_pharmacy_order` uses it, together with the caller's profile, to
   * return the existing order instead of inserting a duplicate row and
   * decrementing stock again when the same attempt is submitted more than
   * once. `null`/omitted disables that protection.
   */
  idempotencyKey?: string | null;
}

/**
 * The exact `place_pharmacy_order` argument object -- a subset of
 * `Database['public']['Functions']['place_pharmacy_order']['Args']`.
 * `p_delivery_address_id` is intentionally not sent (saved-address checkout
 * is a deferred fast-follow in Flutter too), so the RPC's `default null`
 * applies.
 */
export interface PharmacyOrderRpcParams {
  p_recipient_name: string;
  p_phone: string;
  p_street: string;
  p_district: string;
  p_city: string;
  p_delivery_instructions: string;
  p_items: { product_id: string; quantity: number }[];
  p_idempotency_key: string | null;
}

/** Ports `PharmacyOrderLineInput.toRpcMap`, including its validation. */
export function pharmacyOrderLineToRpcMap(line: PharmacyOrderLineInput): { product_id: string; quantity: number } {
  if (line.productId.trim().length === 0) {
    throw new Error('A pharmacy product ID is required.');
  }
  if (!Number.isFinite(line.quantity) || line.quantity <= 0) {
    throw new Error('Pharmacy quantity must be positive.');
  }
  return { product_id: line.productId, quantity: line.quantity };
}

/** Ports `PharmacyOrderRequest.toRpcParams`, including its validation. */
export function pharmacyOrderRequestToRpcParams(request: PharmacyOrderRequest): PharmacyOrderRpcParams {
  if (request.items.length === 0) {
    throw new Error('A pharmacy order requires at least one item.');
  }
  return {
    ...deliveryDetailsToRpcParams(request.delivery ?? EMPTY_DELIVERY_DETAILS),
    p_delivery_instructions: '',
    p_items: request.items.map(pharmacyOrderLineToRpcMap),
    p_idempotency_key: request.idempotencyKey ?? null,
  };
}

/** The slice of `supabase` {@link placePharmacyOrder} depends on. */
export interface PharmacyOrderSource {
  rpc(name: 'place_pharmacy_order', params: PharmacyOrderRpcParams): PromiseLike<{ data: unknown; error: unknown }>;
}

/**
 * Ports `SupabasePharmacyOrderRepository.placeOrder`: calls
 * `place_pharmacy_order` and returns the server-computed `PlacedOrder`. A
 * PostgREST error (e.g. insufficient stock or missing contact details) is
 * rethrown as-is for the caller to map.
 */
export async function placePharmacyOrder(
  request: PharmacyOrderRequest,
  client: PharmacyOrderSource = supabase as unknown as PharmacyOrderSource,
): Promise<PlacedOrder> {
  const { data, error } = await client.rpc('place_pharmacy_order', pharmacyOrderRequestToRpcParams(request));
  if (error) throw error;
  return parsePlacedOrder(data, 'pharmacy order');
}
