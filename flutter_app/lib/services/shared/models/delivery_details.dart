import 'package:supabase_flutter/supabase_flutter.dart';

/// What checkout collects about delivery: only an optional note (landmark,
/// gate colour, directions). Checkout no longer asks for an address (owner
/// decision, 2026-09-25).
///
/// The recipient name and phone are not sent from here: the `place_*_order`
/// RPCs fill them from the caller's own profile when left blank (migration
/// `20260927010000_make_delivery_address_optional.sql`), so a customer can't
/// order for a name/phone that isn't theirs by accident, and there is one
/// place to keep them up to date (Settings).
class DeliveryDetails {
  const DeliveryDetails({this.note = ''});

  final String note;

  /// The address parameters shared by all three order RPCs. The note goes
  /// into `p_street`, which merchants see as the delivery line.
  Map<String, String> toRpcParams() => {
    'p_recipient_name': '',
    'p_phone': '',
    'p_street': note.trim(),
    'p_district': '',
    'p_city': '',
  };
}

/// Raised by the order RPCs when the caller's profile has no name or phone
/// to deliver to. Shown to the customer as-is, since it tells them exactly
/// what to fix.
const missingContactDetailsMessage =
    'Add your name and phone number in Settings before ordering';

/// The message to show when placing an order failed: the server's own
/// message for a missing name/phone, otherwise [fallback].
String describeOrderSaveError(Object error, String fallback) {
  if (error is PostgrestException &&
      error.message.contains(missingContactDetailsMessage)) {
    return '$missingContactDetailsMessage.';
  }
  return fallback;
}
