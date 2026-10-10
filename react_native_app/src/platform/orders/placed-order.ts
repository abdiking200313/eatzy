/**
 * Ports `flutter_app/lib/services/shared/data/rpc_helpers.dart` (issue #378
 * / P5-03): the shared helpers for unwrapping a `place_*_order` RPC
 * response, used by the food, grocery, and pharmacy repositories.
 *
 * Every fee/tax constant lives in a single server-owned `service_pricing`
 * config table (see
 * `supabase/migrations/20260915000000_add_service_pricing_config.sql`), and
 * each RPC `returns table(order_id uuid, subtotal integer, delivery_fee
 * integer, tax integer, total integer)`, so the client reads back the
 * server's authoritative pricing instead of only an id -- see
 * `PlacedOrder`.
 */

/**
 * The authoritative pricing breakdown a `place_*_order` RPC returns for the
 * order it just placed -- or, on an idempotent retry, the matching existing
 * order returned instead of a duplicate. All amounts are integer cents.
 *
 * `tax` is always present for a uniform shape across verticals, even
 * though only food currently charges tax -- grocery and pharmacy always
 * return `0` (see the `service_pricing` seed data).
 */
export interface PlacedOrder {
  orderId: string;
  /** In integer cents, computed server-side from live catalog prices. */
  subtotal: number;
  /** In integer cents, read from `service_pricing` by the RPC. */
  deliveryFee: number;
  /**
   * In integer cents, read from `service_pricing` by the RPC. `0` for
   * verticals that do not charge tax.
   */
  tax: number;
  /**
   * In integer cents: `subtotal + deliveryFee + tax`, as actually charged
   * and returned by the RPC -- this is the value that must be
   * displayed/recorded post-order, never a client-computed cart total,
   * which can be stale if a price changed between the cart being built and
   * checkout being confirmed.
   */
  total: number;
}

/**
 * Extracts a required id from an RPC response `value`, trimming whitespace
 * and validating it is non-empty.
 *
 * `label` describes what the RPC was for (e.g. `'grocery order'`) and is
 * used to build the error message when `value` does not contain a usable
 * id.
 */
export function requiredRpcId(value: unknown, label: string): string {
  const id = typeof value === 'string' || typeof value === 'number' ? String(value).trim() : '';
  if (!id) {
    throw new Error(`The ${label} RPC did not return an ID.`);
  }
  return id;
}

function requiredCents(row: Record<string, unknown>, key: string, label: string): number {
  const value = row[key];
  const parsed = typeof value === 'number' ? Math.round(value) : parseInt(String(value ?? ''), 10);
  if (Number.isNaN(parsed)) {
    throw new Error(`The ${label} RPC row is missing ${key}.`);
  }
  return parsed;
}

/**
 * Parses the single row a `place_*_order` RPC now returns. The Supabase JS
 * client decodes a set-returning RPC call as an array of row objects; these
 * RPCs always return exactly one row (the freshly-placed order, or the
 * existing one on an idempotent retry), so the first element is used.
 *
 * `label` describes what the RPC was for (e.g. `'grocery order'`) and is
 * used to build the error message when `value` does not contain a usable
 * row.
 */
export function parsePlacedOrder(value: unknown, label: string): PlacedOrder {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error(`The ${label} RPC did not return a row.`);
  }
  const row = value[0];
  if (row === null || typeof row !== 'object') {
    throw new Error(`The ${label} RPC returned an invalid row.`);
  }
  const record = row as Record<string, unknown>;
  return {
    orderId: requiredRpcId(record.order_id, label),
    subtotal: requiredCents(record, 'subtotal', label),
    deliveryFee: requiredCents(record, 'delivery_fee', label),
    tax: requiredCents(record, 'tax', label),
    total: requiredCents(record, 'total', label),
  };
}
