/**
 * Ports `flutter_app/lib/features/merchant/orders/models/merchant_order_vertical.dart`
 * (issue #408 / P9-03): per-vertical order table/column/RPC configuration,
 * mirroring how `../../store/api/merchant-vertical.ts` captures per-vertical
 * store columns rather than forcing one fictitious common shape.
 *
 * The Dart header lists the exact migrations every name here was verified
 * against (`20260727152319_connect_super_app_services.sql`,
 * `20260903000000_convert_money_columns_to_cents.sql`,
 * `20260917000000_add_shared_delivery_addresses.sql`,
 * `20260830140000_add_order_status_transition_rpcs.sql`,
 * `20260920000000_add_merchant_order_read_policies.sql`, ...).
 */
import type { MerchantVertical } from '../../store/api/merchant-vertical';

export interface MerchantOrderVerticalConfig {
  /** The order table for this vertical. */
  orderTable: 'food_orders' | 'grocery_orders' | 'pharmacy_orders';
  /** The order line-item table for this vertical (also the embedded-select key on each order row). */
  orderItemsTable: 'food_order_items' | 'grocery_order_items' | 'pharmacy_order_items';
  /**
   * The foreign-key column on {@link orderTable} pointing at the owning
   * store, or `null` for pharmacy -- `pharmacy_orders` has no store column
   * at all, so a pharmacy order list relies on RLS alone
   * (`public.merchant_owns_order`), with no client-side filter on top.
   */
  orderStoreColumn: 'restaurant_id' | 'store_id' | null;
  /** The item-name column on {@link orderItemsTable}. */
  orderItemNameColumn: 'item_name' | 'product_name';
  /** The `advance_*_order_status(p_order_id uuid, p_new_status text)` RPC. */
  advanceOrderStatusRpc: 'advance_food_order_status' | 'advance_grocery_order_status' | 'advance_pharmacy_order_status';
  /** Only `food_orders` has a `tax` column. */
  orderHasTax: boolean;
  /** Only `grocery_orders` has `delivery_slot_label` / `substitution_preference`. */
  orderHasDeliverySlot: boolean;
  /** Only `pharmacy_orders` has `delivery_instructions`. */
  orderHasDeliveryInstructions: boolean;
  /**
   * The forward status vocabulary, read off `is_legal_order_status_transition`
   * (excluding `cancelled`, reachable from either of the first two states --
   * see {@link canCancelOrder}).
   */
  orderStatusFlow: readonly string[];
}

export const MERCHANT_ORDER_VERTICAL_CONFIG: Readonly<Record<MerchantVertical, MerchantOrderVerticalConfig>> = {
  food: {
    orderTable: 'food_orders',
    orderItemsTable: 'food_order_items',
    orderStoreColumn: 'restaurant_id',
    orderItemNameColumn: 'item_name',
    advanceOrderStatusRpc: 'advance_food_order_status',
    orderHasTax: true,
    orderHasDeliverySlot: false,
    orderHasDeliveryInstructions: false,
    orderStatusFlow: ['confirmed', 'preparing', 'out_for_delivery', 'delivered'],
  },
  grocery: {
    orderTable: 'grocery_orders',
    orderItemsTable: 'grocery_order_items',
    orderStoreColumn: 'store_id',
    orderItemNameColumn: 'product_name',
    advanceOrderStatusRpc: 'advance_grocery_order_status',
    orderHasTax: false,
    orderHasDeliverySlot: true,
    orderHasDeliveryInstructions: false,
    orderStatusFlow: ['confirmed', 'shopping', 'out_for_delivery', 'delivered'],
  },
  pharmacy: {
    orderTable: 'pharmacy_orders',
    orderItemsTable: 'pharmacy_order_items',
    orderStoreColumn: null,
    orderItemNameColumn: 'product_name',
    advanceOrderStatusRpc: 'advance_pharmacy_order_status',
    orderHasTax: false,
    orderHasDeliverySlot: false,
    orderHasDeliveryInstructions: true,
    orderStatusFlow: ['confirmed', 'packing', 'out_for_delivery', 'delivered'],
  },
};

const STATUS_LABELS: Readonly<Record<string, string>> = {
  confirmed: 'Confirmed',
  preparing: 'Preparing',
  shopping: 'Shopping',
  packing: 'Packing',
  out_for_delivery: 'Out for delivery',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
};

/** Mirrors `merchantOrderStatusLabel`: falls back to the raw value for anything unrecognized. */
export function merchantOrderStatusLabel(status: string): string {
  return Object.prototype.hasOwnProperty.call(STATUS_LABELS, status) ? STATUS_LABELS[status] : status;
}

/**
 * Mirrors `nextForwardOrderStatus`: the next forward status after `status`,
 * or `null` if `status` is unrecognized or already terminal. The RPC stays
 * the enforcement point; this only decides what to offer.
 */
export function nextForwardOrderStatus(vertical: MerchantVertical, status: string): string | null {
  const flow = MERCHANT_ORDER_VERTICAL_CONFIG[vertical].orderStatusFlow;
  const index = flow.indexOf(status);
  if (index === -1 || index === flow.length - 1) return null;
  return flow[index + 1];
}

/** Mirrors `canCancelOrder`: only the vertical's first two forward states may move to `cancelled`. */
export function canCancelOrder(vertical: MerchantVertical, status: string): boolean {
  const index = MERCHANT_ORDER_VERTICAL_CONFIG[vertical].orderStatusFlow.indexOf(status);
  return index === 0 || index === 1;
}
