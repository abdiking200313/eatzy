/**
 * Ports `flutter_app/lib/platform/activity/data/activity_repository.dart`'s
 * `SupabaseActivityRepository`. `fetchActivities` landed first (issue #373 /
 * P4-02, for the home screen's Recent Activity preview); issue #397 / P8-01
 * adds the rest of the API -- `fetchOrderById`, `fetchOrderDetails`,
 * `watchOrder` -- plus `watchCustomerOrders`, the feed-wide realtime
 * subscription the Activity tab uses to refresh rows live (Flutter has no
 * direct equivalent: its feed only reloads on tab focus/pull-to-refresh,
 * and only `TrackOrderScreen` watches a single order).
 *
 * Realtime subscribes to the per-vertical order tables, not
 * `customer_activity`: that's a view, and Realtime `postgres_changes` only
 * carries base-table changes. The tables were added to the
 * `supabase_realtime` publication by
 * `supabase/migrations/20261004000000_enable_realtime_on_order_tables.sql`
 * (issue #297), and RLS (`auth.uid() = profile_id`) scopes every event to
 * the subscriber's own orders.
 */
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { supabase } from '@/platform/supabase/client';
import type { ServiceId } from '@/theme/service-theme';

import { parseActivityItem, type ActivityItem } from './activity-item';
import { orderDetailsFromRow, type OrderDetails } from './order-details';

const CUSTOMER_ACTIVITY_COLUMNS =
  'id, profile_id, service_id, title, subtitle, status, occurred_at, amount, details_route, payment_method, payment_status';

interface CustomerActivityRow {
  id: string;
  profile_id: string;
  service_id: string;
  title: string;
  subtitle: string | null;
  status: string;
  occurred_at: string;
  amount: number;
  details_route: string;
  payment_method: string | null;
  payment_status: string | null;
}

/**
 * The slice of `supabase` {@link fetchActivities} depends on, narrowed the
 * same way `merchant-role-service.ts`'s `ProfileRoleSource` narrows its own
 * Supabase dependency -- lets a test inject a fake (e.g.
 * `src/test-utils/fake-supabase-client.ts`, plus a plain `auth.getSession`
 * stub, since the fake itself has no `auth` namespace) instead of the real
 * client.
 */
export interface ActivitySource {
  auth: {
    getSession(): Promise<{ data: { session: { user: { id: string } } | null } }>;
  };
  from(table: 'customer_activity'): {
    select(columns: string): {
      eq(
        column: 'profile_id',
        value: string,
      ): {
        order(
          column: 'occurred_at',
          options: { ascending: boolean },
        ): {
          limit(count: number): PromiseLike<{ data: CustomerActivityRow[] | null; error: { message: string } | null }>;
        };
      };
    };
  };
}

/** Mirrors `SupabaseActivityRepository.fetchActivities`'s `RangeError`. */
export class InvalidActivityLimitError extends RangeError {
  constructor(limit: number) {
    super(`limit must be between 1 and 100, got ${limit}`);
  }
}

/**
 * Fetches the signed-in user's cross-vertical activity feed, most recent
 * first. Parses each row independently: one malformed row (missing/blank
 * field, an unparseable date or amount, etc.) must not blank the whole
 * activity list -- it's skipped and reported instead.
 */
export async function fetchActivities(
  client: ActivitySource = supabase as unknown as ActivitySource,
  limit = 100,
): Promise<ActivityItem[]> {
  if (limit < 1 || limit > 100) {
    throw new InvalidActivityLimitError(limit);
  }
  const {
    data: { session },
  } = await client.auth.getSession();
  const profileId = session?.user.id;
  if (!profileId) {
    throw new Error('Sign in before loading customer activity.');
  }

  const { data, error } = await client
    .from('customer_activity')
    .select(CUSTOMER_ACTIVITY_COLUMNS)
    .eq('profile_id', profileId)
    .order('occurred_at', { ascending: false })
    .limit(limit);
  if (error) throw error;

  const items: ActivityItem[] = [];
  for (const row of data ?? []) {
    try {
      items.push(parseActivityItem(row as unknown as Record<string, unknown>));
    } catch (parseError) {
      ErrorReporting.instance.reportError(
        parseError,
        parseError instanceof Error ? parseError.stack : undefined,
        'fetchActivities',
      );
    }
  }
  return items;
}

// --- Single-order lookups (ports `OrderDetailsSource`) -----------------------

type QueryResult<T> = PromiseLike<{ data: T | null; error: { message: string } | null }>;

interface RowFilterBuilder extends QueryResult<Record<string, unknown>[]> {
  eq(column: string, value: string): RowFilterBuilder;
  maybeSingle(): QueryResult<Record<string, unknown>>;
}

/**
 * The slice of `supabase` {@link fetchOrderById}/{@link fetchOrderDetails}
 * depend on -- loose enough to read any of `customer_activity` and the three
 * per-vertical order tables, and satisfied structurally by
 * `src/test-utils/fake-supabase-client.ts` plus an `auth` stub.
 */
export interface OrderDetailsSource {
  auth: ActivitySource['auth'];
  from(table: string): { select(columns: string): RowFilterBuilder };
}

const defaultOrderDetailsSource = () => supabase as unknown as OrderDetailsSource;

/**
 * Ports `fetchOrderById`: the caller's own `customer_activity` row for this
 * id/service, or `null` when no row matches -- either it doesn't exist or
 * RLS already scoped it away (indistinguishable by design). Throws when
 * no one is signed in. A malformed row is reported and treated as `null`.
 */
export async function fetchOrderById(
  options: { orderId: string; serviceId: string },
  client: OrderDetailsSource = defaultOrderDetailsSource(),
): Promise<ActivityItem | null> {
  const {
    data: { session },
  } = await client.auth.getSession();
  const profileId = session?.user.id;
  if (!profileId) {
    throw new Error('Sign in before loading order details.');
  }

  // `.eq('profile_id', ...)` is redundant with RLS but kept explicit, same
  // as the Dart source, so the intent is readable from the query itself.
  const { data, error } = await client
    .from('customer_activity')
    .select(CUSTOMER_ACTIVITY_COLUMNS)
    .eq('profile_id', profileId)
    .eq('id', options.orderId)
    .eq('service_id', options.serviceId)
    .maybeSingle();
  if (error) throw error;
  if (data == null) return null;

  try {
    return parseActivityItem(data);
  } catch (parseError) {
    ErrorReporting.instance.reportError(
      parseError,
      parseError instanceof Error ? parseError.stack : undefined,
      'fetchOrderById',
    );
    return null;
  }
}

interface OrderTableShape {
  table: string;
  itemsTable: string;
  itemName: string;
  extra: string;
}

function orderTableShape(serviceId: ServiceId): OrderTableShape | null {
  switch (serviceId) {
    case 'food':
      return { table: 'food_orders', itemsTable: 'food_order_items', itemName: 'item_name', extra: 'restaurant_name, tax' };
    case 'grocery':
      return { table: 'grocery_orders', itemsTable: 'grocery_order_items', itemName: 'product_name', extra: 'store_name, delivery_slot_label' };
    case 'pharmacy':
      return { table: 'pharmacy_orders', itemsTable: 'pharmacy_order_items', itemName: 'product_name', extra: 'delivery_instructions' };
    default:
      return null;
  }
}

/** Ports `fetchOrderDetails`: {@link fetchOrderById} plus the order's lines, charges and delivery address. Same `null` contract. */
export async function fetchOrderDetails(
  options: { orderId: string; serviceId: string },
  client: OrderDetailsSource = defaultOrderDetailsSource(),
): Promise<OrderDetails | null> {
  const summary = await fetchOrderById(options, client);
  if (summary == null) return null;

  const shape = orderTableShape(summary.serviceId);
  if (shape == null) return null;

  const itemColumns = [shape.itemName, 'quantity', 'unit_price', ...(summary.serviceId === 'grocery' ? ['pricing_unit'] : [])].join(', ');
  // RLS already scopes each order table to the caller's own rows.
  const { data, error } = await client
    .from(shape.table)
    .select(`subtotal, delivery_fee, total, recipient_name, phone, street, district, city, ${shape.extra}, ${shape.itemsTable}(${itemColumns})`)
    .eq('id', options.orderId)
    .maybeSingle();
  if (error) throw error;
  if (data == null) return null;
  return orderDetailsFromRow(summary, data, { itemsKey: shape.itemsTable, itemNameColumn: shape.itemName });
}

// --- Realtime ----------------------------------------------------------------

/** What a Realtime `postgres_changes` callback receives -- only the parts read here. */
export interface OrderChangePayload {
  new?: Record<string, unknown> | null;
  old?: Record<string, unknown> | null;
}

/** The slice of a Supabase `RealtimeChannel` used here. */
export interface RealtimeChannelLike {
  on(
    type: 'postgres_changes',
    filter: { event: '*'; schema: 'public'; table: string; filter?: string },
    callback: (payload: OrderChangePayload) => void,
  ): RealtimeChannelLike;
  subscribe(): unknown;
}

/** The slice of `supabase` the realtime helpers depend on, so tests can inject a fake channel. */
export interface RealtimeSource {
  channel(name: string): RealtimeChannelLike;
  removeChannel(channel: RealtimeChannelLike): unknown;
}

const defaultRealtimeSource = () => supabase as unknown as RealtimeSource;

/** The per-vertical order table each real service's orders live in. */
export const ORDER_TABLES: readonly { serviceId: Exclude<ServiceId, 'unknown'>; table: string }[] = [
  { serviceId: 'food', table: 'food_orders' },
  { serviceId: 'grocery', table: 'grocery_orders' },
  { serviceId: 'pharmacy', table: 'pharmacy_orders' },
];

/**
 * Ports `watchOrder`: calls `onChange` (no payload -- refetch via
 * {@link fetchOrderDetails} rather than trusting the event's shape) every
 * time this one order's row changes server-side, e.g. a merchant moving it
 * to `preparing`. Filtered to this order's own row only. Returns a function
 * that stops watching. An unknown `serviceId` watches nothing.
 */
export function watchOrder(
  options: { orderId: string; serviceId: string },
  onChange: () => void,
  client: RealtimeSource = defaultRealtimeSource(),
): () => void {
  const table = ORDER_TABLES.find((entry) => entry.serviceId === options.serviceId)?.table;
  if (table == null) return () => {};

  const channel = client
    .channel(`order-watch:${table}:${options.orderId}`)
    .on('postgres_changes', { event: '*', schema: 'public', table, filter: `id=eq.${options.orderId}` }, () => onChange());
  channel.subscribe();
  let active = true;
  return () => {
    if (!active) return;
    active = false;
    void client.removeChannel(channel);
  };
}

/** One changed order, as reported by {@link watchCustomerOrders}. */
export interface CustomerOrderChange {
  serviceId: Exclude<ServiceId, 'unknown'>;
  orderId: string;
}

/**
 * Feed-wide realtime for the Activity tab: one channel listening to all
 * three order tables, filtered to `profileId`'s own orders
 * (`profile_id=eq.<id>`, on top of RLS). Calls `onChange` with the changed
 * order's service and id (the payload is trusted only for the row id --
 * callers refetch the row itself). Returns a function that stops watching.
 */
export function watchCustomerOrders(
  profileId: string,
  onChange: (change: CustomerOrderChange) => void,
  client: RealtimeSource = defaultRealtimeSource(),
): () => void {
  let channel = client.channel(`activity-feed:${profileId}`);
  for (const { serviceId, table } of ORDER_TABLES) {
    channel = channel.on('postgres_changes', { event: '*', schema: 'public', table, filter: `profile_id=eq.${profileId}` }, (payload) => {
      const rawId = payload.new?.id ?? payload.old?.id;
      if (rawId == null || String(rawId).length === 0) return;
      onChange({ serviceId, orderId: String(rawId) });
    });
  }
  channel.subscribe();
  let active = true;
  return () => {
    if (!active) return;
    active = false;
    void client.removeChannel(channel);
  };
}
