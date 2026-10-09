/// Order date/time formatting (issue #356).
///
/// Ports the one date/time format string order-tracking screens actually use
/// in the Flutter app -- `DateFormat('MMM d, yyyy · h:mm a')`, applied to
/// `summary.occurredAt.toLocal()` in
/// `flutter_app/lib/features/orders/presentation/widgets/order_details_content.dart`
/// -- rather than introducing new formatting the Flutter app doesn't have.

const shortDateFormatter = new Intl.DateTimeFormat('en-US', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
});

const orderTimeFormatter = new Intl.DateTimeFormat('en-US', {
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

/**
 * Formats a `Date` (interpreted in local time, matching the Flutter screen's
 * `.toLocal()`) as `"MMM d, yyyy · h:mm a"`, e.g. `"Jan 5, 2024 · 3:45 PM"`.
 * Used wherever an order's `occurredAt` timestamp is shown to the customer.
 */
export function formatOrderDateTime(date: Date): string {
  return `${shortDateFormatter.format(date)} · ${orderTimeFormatter.format(date)}`;
}

/**
 * Formats a `Date` as `"MMM d, yyyy"` (e.g. `"Jan 5, 2024"`) -- mirrors
 * `DateFormat('MMM d, yyyy').format(picked)` from
 * `flutter_app/lib/features/auth/presentation/register_screen.dart`'s
 * `_pickDob`, used to render the selected date-of-birth value in the
 * register screen's read-only text field (issue #366).
 */
export function formatShortDate(date: Date): string {
  return shortDateFormatter.format(date);
}
