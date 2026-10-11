/**
 * Ports `flutter_app/lib/features/merchant/orders/data/merchant_orders_repository.dart`
 * (issue #408 / P9-03): data access for the signed-in merchant's own orders
 * -- `food_orders` / `grocery_orders` / `pharmacy_orders`, scoped to the
 * caller's own store by the merchant select policies
 * (`20260920000000_add_merchant_order_read_policies.sql`), with status
 * changes going exclusively through the `advance_*_order_status` RPCs (no
 * direct table writes).
 *
 * RN addition: {@link MerchantOrdersRepository.watchOrders}, the realtime
 * subscription the issue asks for. The Dart Orders screen has none (it only
 * offers pull-to-refresh); this reuses the P8-02 realtime plumbing from
 * `@/platform/activity/api/activity-repository` (`RealtimeSource`), and the
 * three order tables were added to the `supabase_realtime` publication by
 * `20261004000000_enable_realtime_on_order_tables.sql`. Realtime applies the
 * subscriber's RLS select policies to INSERT/UPDATE events, so a merchant
 * only hears about orders they can already read.
 */
import type { RealtimeSource } from '@/platform/activity/api/activity-repository';
import { supabase } from '@/platform/supabase/client';

import type { MerchantVertical } from '../../store/api/merchant-vertical';
import { merchantOrderFromRow, type MerchantOrder } from './merchant-order';
import { MERCHANT_ORDER_VERTICAL_CONFIG } from './merchant-order-vertical';
import { OrderStatusTransitionError } from './order-status-transition-error';

export { OrderStatusTransitionError };

type Row = Record<string, unknown>;
type SupabaseResult<T> = { data: T | null; error: { message?: string } | null };

interface OrderFilterChain extends PromiseLike<SupabaseResult<Row[]>> {
  eq(column: string, value: unknown): OrderFilterChain;
  order(column: string, options: { ascending: boolean }): OrderFilterChain;
  limit(count: number): OrderFilterChain;
}

/** The slice of `supabase` {@link SupabaseMerchantOrdersRepository} depends on, so a test can inject the fake client. */
export interface MerchantOrdersSource {
  from(table: string): { select(columns: string): OrderFilterChain };
  rpc(name: string, params: Record<string, unknown>): PromiseLike<SupabaseResult<unknown>>;
}

export interface FetchMerchantOrdersInput {
  vertical: MerchantVertical;
  storeId: string;
}

export interface AdvanceOrderStatusInput {
  vertical: MerchantVertical;
  orderId: string;
  newStatus: string;
}

export interface MerchantOrdersRepository {
  /** Every order belonging to `storeId` in `vertical`, newest first, each with its line items. */
  fetchOrders(input: FetchMerchantOrdersInput): Promise<MerchantOrder[]>;

  /**
   * Calls `advance_<vertical>_order_status(p_order_id, p_new_status)`,
   * resolving the new status. Rejects with {@link OrderStatusTransitionError}
   * if the server rejects the transition.
   */
  advanceOrderStatus(input: AdvanceOrderStatusInput): Promise<string>;

  /**
   * RN-only (no Dart counterpart): calls `onChange` whenever an order for
   * `storeId` in `vertical` is inserted or changes server-side. No payload --
   * callers refetch rather than trusting the event's shape (the event row
   * carries no line items). Returns a function that stops watching.
   */
  watchOrders(input: FetchMerchantOrdersInput, onChange: () => void): () => void;
}

/** Mirrors `SupabaseMerchantOrdersRepository.maxOrdersPerStore`. */
export const MAX_ORDERS_PER_STORE = 500;

function orderColumns(vertical: MerchantVertical): string[] {
  const config = MERCHANT_ORDER_VERTICAL_CONFIG[vertical];
  return [
    'id',
    'status',
    'created_at',
    'subtotal',
    'delivery_fee',
    ...(config.orderHasTax ? ['tax'] : []),
    'total',
    'recipient_name',
    'phone',
    'street',
    'district',
    'city',
    ...(config.orderHasDeliverySlot ? ['delivery_slot_label', 'substitution_preference'] : []),
    ...(config.orderHasDeliveryInstructions ? ['delivery_instructions'] : []),
    'payment_method',
    'payment_status',
  ];
}

/** Mirrors the Dart `_selection`: order columns plus the embedded line-item relation. */
export function merchantOrderSelection(vertical: MerchantVertical): string {
  const config = MERCHANT_ORDER_VERTICAL_CONFIG[vertical];
  const itemColumns = ['id', config.orderItemNameColumn, 'quantity', 'unit_price'].join(', ');
  return `${orderColumns(vertical).join(', ')}, ${config.orderItemsTable}(${itemColumns})`;
}

export class SupabaseMerchantOrdersRepository implements MerchantOrdersRepository {
  private readonly client: MerchantOrdersSource;
  private readonly realtime: RealtimeSource;

  constructor(
    client: MerchantOrdersSource = supabase as unknown as MerchantOrdersSource,
    realtime: RealtimeSource = supabase as unknown as RealtimeSource,
  ) {
    this.client = client;
    this.realtime = realtime;
  }

  async fetchOrders({ vertical, storeId }: FetchMerchantOrdersInput): Promise<MerchantOrder[]> {
    const config = MERCHANT_ORDER_VERTICAL_CONFIG[vertical];
    let query = this.client.from(config.orderTable).select(merchantOrderSelection(vertical));
    // Pharmacy orders have no store column to filter on client-side; the
    // merchant-scoped select policy is the only thing narrowing that set.
    if (config.orderStoreColumn != null) {
      query = query.eq(config.orderStoreColumn, storeId);
    }
    const { data, error } = await query.order('created_at', { ascending: false }).limit(MAX_ORDERS_PER_STORE);
    if (error) throw error;
    return (data ?? []).map((row) => merchantOrderFromRow(row, vertical));
  }

  async advanceOrderStatus({ vertical, orderId, newStatus }: AdvanceOrderStatusInput): Promise<string> {
    const { data, error } = await this.client.rpc(MERCHANT_ORDER_VERTICAL_CONFIG[vertical].advanceOrderStatusRpc, {
      p_order_id: orderId,
      p_new_status: newStatus,
    });
    if (error) throw new OrderStatusTransitionError(error.message ?? 'The order status could not be updated.');
    return typeof data === 'string' ? data : newStatus;
  }

  watchOrders({ vertical, storeId }: FetchMerchantOrdersInput, onChange: () => void): () => void {
    const config = MERCHANT_ORDER_VERTICAL_CONFIG[vertical];
    // Same store scoping as `fetchOrders`: food/grocery filter on the store
    // FK; pharmacy has no store column, so it relies on RLS alone.
    const filter = config.orderStoreColumn == null ? undefined : `${config.orderStoreColumn}=eq.${storeId}`;
    const channel = this.realtime
      .channel(`merchant-orders:${config.orderTable}:${storeId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: config.orderTable, ...(filter ? { filter } : {}) }, () =>
        onChange(),
      );
    channel.subscribe();
    let active = true;
    return () => {
      if (!active) return;
      active = false;
      void this.realtime.removeChannel(channel);
    };
  }
}
