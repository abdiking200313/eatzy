/**
 * Ports `flutter_app/lib/platform/activity/models/activity_item.dart`'s
 * `ActivityItem` (issue #373 / P4-02's "read path of activity_repository.dart",
 * reused by #397 / P8-01's full activity feed).
 */
import { trackOrderDetailsPath } from '@/platform/navigation/app-routes';
import type { ServiceId } from '@/theme/service-theme';

export interface ActivityItem {
  id: string;
  serviceId: ServiceId;
  title: string;
  subtitle?: string;
  status: string;
  occurredAt: Date;
  /** In integer cents. Convert to decimal dollars only at display time. */
  amount: number;
  detailsRoute: string;
  /**
   * Raw `payment_method`/`payment_status` values from the order row
   * (cash-on-delivery-only launch scaffolding). Today's only real values
   * are `cash_on_delivery` and `pending_collection`.
   */
  paymentMethod?: string;
  paymentStatus?: string;
}

/** Mirrors `ActivityItem.paymentMethodLabel`. */
export function paymentMethodLabel(item: ActivityItem): string | undefined {
  if (item.paymentMethod === undefined) return undefined;
  return item.paymentMethod === 'cash_on_delivery' ? 'Cash on delivery' : item.paymentMethod;
}

/** Mirrors `ActivityItem.paymentStatusLabel`. */
export function paymentStatusLabel(item: ActivityItem): string | undefined {
  switch (item.paymentStatus) {
    case undefined:
      return undefined;
    case 'pending_collection':
      return 'Pending collection';
    case 'collected':
      return 'Collected';
    case 'refunded':
      return 'Refunded';
    default:
      return item.paymentStatus;
  }
}

/**
 * Mirrors `ActivityItem.orderDetailsPath`: `null`/`undefined` for an
 * `'unknown'` row -- `parseActivityItem` has already discarded its raw
 * `service_id`, so there is nothing real to key the lookup on.
 */
export function orderDetailsPath(item: ActivityItem): string | undefined {
  if (item.serviceId === 'unknown') return undefined;
  return trackOrderDetailsPath({ serviceId: item.serviceId, orderId: item.id });
}

function requiredString(row: Record<string, unknown>, key: string): string {
  const value = row[key]?.toString().trim();
  if (!value) {
    throw new Error(`Missing required activity field: ${key}`);
  }
  return value;
}

function optionalString(row: Record<string, unknown>, key: string): string | undefined {
  const value = row[key]?.toString().trim();
  return value ? value : undefined;
}

/**
 * Mirrors `ActivityItem.fromMap`: an unrecognized `service_id` falls back
 * to `'unknown'` rather than throwing (a single row with a service id this
 * client doesn't yet recognize should render as a generic activity entry,
 * not take down the rest of the list). Other malformed fields still throw
 * -- the caller (`fetchActivities`) catches that per row and skips just
 * the bad row.
 */
export function parseActivityItem(row: Record<string, unknown>): ActivityItem {
  const rawServiceId = requiredString(row, 'service_id');
  const serviceId: ServiceId = rawServiceId === 'food' || rawServiceId === 'grocery' || rawServiceId === 'pharmacy' ? rawServiceId : 'unknown';

  const occurredAtRaw = requiredString(row, 'occurred_at');
  const occurredAt = new Date(occurredAtRaw);
  if (Number.isNaN(occurredAt.getTime())) {
    throw new Error('Invalid activity occurrence time.');
  }

  const rawAmount = row.amount;
  const amount = typeof rawAmount === 'number' ? Math.round(rawAmount) : parseInt(String(rawAmount ?? ''), 10);
  if (Number.isNaN(amount) || amount < 0) {
    throw new Error('Invalid activity amount.');
  }

  return {
    id: requiredString(row, 'id'),
    serviceId,
    title: requiredString(row, 'title'),
    subtitle: optionalString(row, 'subtitle'),
    status: requiredString(row, 'status'),
    occurredAt,
    amount,
    detailsRoute: requiredString(row, 'details_route'),
    paymentMethod: optionalString(row, 'payment_method'),
    paymentStatus: optionalString(row, 'payment_status'),
  };
}
