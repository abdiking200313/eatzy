/**
 * Ports `flutter_app/lib/platform/activity/models/order_details.dart`
 * (`OrderLine`, `OrderDetails`, `orderStatusLabel`) -- issue #397 / P8-01.
 * Read back by `fetchOrderDetails` in `activity-repository.ts`; rendered by
 * the order details/tracking screen (#398 / P8-02).
 */
import type { ServiceId } from '@/theme/service-theme';

import type { ActivityItem } from './activity-item';

/** One line of a past order, at the price paid then (integer cents). Ports `OrderLine`. */
export interface OrderLine {
  name: string;
  /** Whole for food/pharmacy; grocery `kilogram` lines can be fractional. */
  quantity: number;
  unitPrice: number;
  /** Grocery only: `each` or `kilogram`. */
  pricingUnit?: string;
}

/** Ports `OrderLine.lineTotal`. */
export function orderLineTotal(line: OrderLine): number {
  return Math.round(line.unitPrice * line.quantity);
}

/** Ports `OrderLine.quantityLabel`: `2x`, or `1.5 kg` for a kilogram line. */
export function orderLineQuantityLabel(line: OrderLine): string {
  // JS already prints a whole number without a trailing `.0` (Dart needs an
  // explicit `round()` for that), so plain `String` matches both branches.
  const amount = String(line.quantity);
  return line.pricingUnit === 'kilogram' ? `${amount} kg` : `${amount}x`;
}

/**
 * A customer's own order as shown on the order details page: the
 * `customer_activity` summary plus the order row's lines, charges and
 * delivery address (all money in integer cents). Ports `OrderDetails`.
 */
export interface OrderDetails {
  summary: ActivityItem;
  lines: OrderLine[];
  subtotal: number;
  deliveryFee: number;
  /** Food only. */
  tax?: number;
  total: number;
  storeName?: string;
  recipientName?: string;
  phone?: string;
  street?: string;
  district?: string;
  city?: string;
  /** Grocery delivery slot or pharmacy delivery instructions. */
  deliveryNote?: string;
}

/** Ports `OrderDetails.addressLine`: "Street, District, City" with blank parts dropped; `undefined` when there's no address at all. */
export function orderAddressLine(order: OrderDetails): string | undefined {
  const parts = [order.street, order.district, order.city].filter((part): part is string => !!part);
  return parts.length === 0 ? undefined : parts.join(', ');
}

/** Ports `OrderDetails.isCancelled`. */
export function isOrderCancelled(order: OrderDetails): boolean {
  return order.summary.status === 'cancelled';
}

/** Ports `OrderDetails.isFinal`: `delivered`/`cancelled` never transition again, so there's nothing left to watch live. */
export function isOrderFinal(order: OrderDetails): boolean {
  return isOrderCancelled(order) || order.summary.status === 'delivered';
}

/** Ports `OrderDetails.statusFlow`, matching the backend's `is_legal_order_status_transition`. */
export function orderStatusFlow(serviceId: ServiceId): string[] {
  const middle = serviceId === 'grocery' ? 'shopping' : serviceId === 'pharmacy' ? 'packing' : 'preparing';
  return ['confirmed', middle, 'out_for_delivery', 'delivered'];
}

/** Ports `OrderDetails.statusStep`: index of the status in its flow, or -1 when unknown/cancelled. */
export function orderStatusStep(order: OrderDetails): number {
  return orderStatusFlow(order.summary.serviceId).indexOf(order.summary.status);
}

function cents(value: unknown): number {
  return typeof value === 'number' ? Math.round(value) : 0;
}

function text(value: unknown): string | undefined {
  if (value == null) return undefined;
  const trimmed = String(value).trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

/** Ports `OrderDetails.fromOrderRow`. */
export function orderDetailsFromRow(
  summary: ActivityItem,
  row: Record<string, unknown>,
  options: { itemsKey: string; itemNameColumn: string },
): OrderDetails {
  const rawLines = row[options.itemsKey];
  const lines: OrderLine[] = [];
  if (Array.isArray(rawLines)) {
    for (const line of rawLines) {
      if (line == null || typeof line !== 'object') continue;
      const map = line as Record<string, unknown>;
      lines.push({
        name: map[options.itemNameColumn] == null ? 'Item' : String(map[options.itemNameColumn]),
        quantity: typeof map.quantity === 'number' ? map.quantity : 1,
        unitPrice: cents(map.unit_price),
        pricingUnit: text(map.pricing_unit),
      });
    }
  }
  return {
    summary,
    lines,
    subtotal: cents(row.subtotal),
    deliveryFee: cents(row.delivery_fee),
    tax: 'tax' in row ? cents(row.tax) : undefined,
    total: cents(row.total),
    storeName: text(row.restaurant_name) ?? text(row.store_name),
    recipientName: text(row.recipient_name),
    phone: text(row.phone),
    street: text(row.street),
    district: text(row.district),
    city: text(row.city),
    deliveryNote: text(row.delivery_slot_label) ?? text(row.delivery_instructions),
  };
}

/** Ports `orderStatusLabel`: human-readable label for a raw order status value. */
export function orderStatusLabel(status: string): string {
  switch (status) {
    case 'confirmed':
      return 'Confirmed';
    case 'preparing':
      return 'Preparing';
    case 'shopping':
      return 'Shopping';
    case 'packing':
      return 'Packing';
    case 'out_for_delivery':
      return 'Out for delivery';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}
