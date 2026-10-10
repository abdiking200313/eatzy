/**
 * Ports `DeliveryDetails` from
 * `flutter_app/lib/services/shared/models/delivery_details.dart` (issue
 * #381 / P5-06). Checkout only collects an optional delivery note
 * (landmark, gate colour, directions) -- no address (owner decision,
 * 2026-09-25).
 *
 * The recipient name and phone are not sent from here: the
 * `place_*_order` RPCs fill them from the caller's own profile when left
 * blank, so a customer can't order for a name/phone that isn't theirs by
 * accident, and there is one place to keep them up to date (Settings).
 * `missingContactDetailsMessage`/`describeOrderSaveError` (already ported
 * in `order-errors.ts`, issue #378) are what surfaces that as a clear
 * checkout-blocking message when the RPC rejects a profile with no name
 * or phone.
 */

export type DeliveryDetails = {
  note: string;
};

export const EMPTY_DELIVERY_DETAILS: DeliveryDetails = { note: '' };

/**
 * The address parameters shared by all three order RPCs. The note goes
 * into `p_street`, which merchants see as the delivery line.
 */
export function deliveryDetailsToRpcParams(details: DeliveryDetails): {
  p_recipient_name: string;
  p_phone: string;
  p_street: string;
  p_district: string;
  p_city: string;
} {
  return {
    p_recipient_name: '',
    p_phone: '',
    p_street: details.note.trim(),
    p_district: '',
    p_city: '',
  };
}
