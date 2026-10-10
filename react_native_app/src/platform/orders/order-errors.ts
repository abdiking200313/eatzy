/**
 * Ports `describeOrderSaveError`/`missingContactDetailsMessage` from
 * `flutter_app/lib/services/shared/models/delivery_details.dart` (issue
 * #378 / P5-03's "RPC error mapping" -- the issue names
 * `rpc_helpers.dart` for this, but the actual order-error mapping lives in
 * `delivery_details.dart`; checked the Flutter source directly since the
 * issue text predates some file moves).
 */
import { PostgrestError } from '@supabase/supabase-js';

/**
 * Raised by the order RPCs when the caller's profile has no name or phone
 * to deliver to. Shown to the customer as-is, since it tells them exactly
 * what to fix.
 */
export const missingContactDetailsMessage = 'Add your name and phone number in Settings before ordering';

/**
 * The message to show when placing an order failed: the server's own
 * message for a missing name/phone, otherwise `fallback`.
 */
export function describeOrderSaveError(error: unknown, fallback: string): string {
  if (error instanceof PostgrestError && error.message.includes(missingContactDetailsMessage)) {
    return `${missingContactDetailsMessage}.`;
  }
  return fallback;
}
