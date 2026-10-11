/**
 * Ports `flutter_app/lib/features/merchant/orders/models/merchant_order.dart`
 * (issue #408 / P9-03): one order row (plus its line items) from whichever
 * vertical table `MERCHANT_ORDER_VERTICAL_CONFIG[vertical].orderTable`
 * names, for the merchant incoming-order queue.
 *
 * All money fields are integer cents (see `AGENTS.md`); convert to dollars
 * only at display time via `formatCents`.
 */
import type { MerchantVertical } from '../../store/api/merchant-vertical';
import { MERCHANT_ORDER_VERTICAL_CONFIG } from './merchant-order-vertical';

type Row = Record<string, unknown>;

export interface MerchantOrderLineItem {
  id: string;
  name: string;
  /**
   * `food_order_items.quantity` / `pharmacy_order_items.quantity` are
   * integers; `grocery_order_items.quantity` is `numeric(12, 2)` (weighted
   * items, e.g. `2.5` kg) -- a plain `number` covers both.
   */
  quantity: number;
  /** Integer cents. */
  unitPriceCents: number;
}

export interface MerchantOrder {
  id: string;
  vertical: MerchantVertical;
  status: string;
  createdAt: Date;
  subtotalCents: number;
  deliveryFeeCents: number;
  /** `food_orders.tax` only -- `null` for grocery/pharmacy, which have no tax column. */
  taxCents: number | null;
  totalCents: number;
  /** Contact/address snapshot captured at checkout -- shared column names on all three tables. */
  recipientName: string;
  phone: string;
  street: string;
  district: string;
  city: string;
  /** `grocery_orders.delivery_slot_label` only. */
  deliverySlotLabel: string | null;
  /** `grocery_orders.substitution_preference` only (raw value). */
  substitutionPreference: string | null;
  /** `pharmacy_orders.delivery_instructions` only. */
  deliveryInstructions: string | null;
  /** Raw `payment_method` / `payment_status` values; `null` for a row predating those columns. */
  paymentMethod: string | null;
  paymentStatus: string | null;
  items: readonly MerchantOrderLineItem[];
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function numberOrNull(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  // PostgREST serializes `numeric` columns as JSON numbers, but tolerate a
  // numeric string too rather than silently zeroing it.
  if (typeof value === 'string' && value.trim().length > 0 && Number.isFinite(Number(value))) return Number(value);
  return null;
}

/** Dart's `num.round()` rounds half away from zero; `Math.round` rounds half up. */
function roundHalfAwayFromZero(value: number): number {
  return Math.sign(value) * Math.round(Math.abs(value));
}

function centsOrZero(value: unknown): number {
  const parsed = numberOrNull(value);
  return parsed == null ? 0 : roundHalfAwayFromZero(parsed);
}

/** Mirrors `MerchantOrderLineItem.lineTotalCents`: `unitPriceCents * quantity`, rounded to the nearest cent. */
export function lineTotalCents(item: MerchantOrderLineItem): number {
  return roundHalfAwayFromZero(item.unitPriceCents * item.quantity);
}

/** Mirrors `MerchantOrderLineItem.fromMap`. */
export function merchantOrderLineItemFromRow(row: Row, vertical: MerchantVertical): MerchantOrderLineItem {
  const config = MERCHANT_ORDER_VERTICAL_CONFIG[vertical];
  return {
    id: String(row.id),
    name: stringOrNull(row[config.orderItemNameColumn]) ?? '',
    quantity: numberOrNull(row.quantity) ?? 0,
    unitPriceCents: centsOrZero(row.unit_price),
  };
}

function parseCreatedAt(value: unknown): Date {
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return new Date(0);
}

/** Mirrors `MerchantOrder.fromMap`. */
export function merchantOrderFromRow(row: Row, vertical: MerchantVertical): MerchantOrder {
  const config = MERCHANT_ORDER_VERTICAL_CONFIG[vertical];
  const rawItems = Array.isArray(row[config.orderItemsTable]) ? (row[config.orderItemsTable] as Row[]) : [];
  return {
    id: String(row.id),
    vertical,
    status: stringOrNull(row.status) ?? 'confirmed',
    createdAt: parseCreatedAt(row.created_at),
    subtotalCents: centsOrZero(row.subtotal),
    deliveryFeeCents: centsOrZero(row.delivery_fee),
    taxCents: config.orderHasTax ? centsOrZero(row.tax) : null,
    totalCents: centsOrZero(row.total),
    recipientName: stringOrNull(row.recipient_name) ?? '',
    phone: stringOrNull(row.phone) ?? '',
    street: stringOrNull(row.street) ?? '',
    district: stringOrNull(row.district) ?? '',
    city: stringOrNull(row.city) ?? '',
    deliverySlotLabel: config.orderHasDeliverySlot ? stringOrNull(row.delivery_slot_label) : null,
    substitutionPreference: config.orderHasDeliverySlot ? stringOrNull(row.substitution_preference) : null,
    deliveryInstructions: config.orderHasDeliveryInstructions ? stringOrNull(row.delivery_instructions) : null,
    paymentMethod: stringOrNull(row.payment_method),
    paymentStatus: stringOrNull(row.payment_status),
    items: Object.freeze(rawItems.map((item) => merchantOrderLineItemFromRow(item, vertical))),
  };
}

/**
 * Mirrors `MerchantOrder.deliveryLine`: whatever location text the order
 * carries, blanks skipped. Since 2026-09-25 checkout only sends an optional
 * note (stored as the street), so this is often just that note, or empty.
 */
export function deliveryLine(order: Pick<MerchantOrder, 'street' | 'district' | 'city'>): string {
  return [order.street, order.district, order.city]
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
    .join(', ');
}

/** Mirrors `shortOrderId`: the first 8 characters of a uuid, for "Order #1234abcd". */
export function shortOrderId(orderId: string): string {
  return orderId.length <= 8 ? orderId : orderId.substring(0, 8);
}

/** Mirrors `substitutionPreferenceLabel`: falls back to the raw string for anything unrecognized. */
export function substitutionPreferenceLabel(raw: string | null): string | null {
  switch (raw) {
    case null:
      return null;
    case 'best_match':
      return 'Substitute with best match';
    case 'contact_me':
      return 'Contact me before substituting';
    case 'no_substitutions':
      return 'No substitutions';
    default:
      return raw;
  }
}
