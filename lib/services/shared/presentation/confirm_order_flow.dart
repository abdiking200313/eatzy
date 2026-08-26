import 'dart:async';

/// Runs the common "validate, place a demo order, record activity, clear
/// the cart" shell shared by the grocery, pharmacy, and food demo checkout
/// flows.
///
/// The vertical-specific pieces are supplied by the caller:
/// - [validation] is the already-computed validation result.
/// - [isValid] reports whether [validation] passed.
/// - [onInvalid] builds the failure result to return when validation fails.
/// - [placeOrder] performs the repository call; a `null` result falls back
///   to [fallbackOrderId] to synthesize a demo order id (matching prior
///   behavior for controllers without a real order repository configured).
/// - [onSaveFailed] builds the failure result to return if [placeOrder]
///   throws.
/// - [recordActivity] and [clearCart] run, in that order, once an order id
///   is available, before [onConfirmed] builds the success result.
///   [clearCart] may return a `Future` (e.g. a cart backed by persisted
///   storage) or complete synchronously; either way it is awaited before
///   [onConfirmed] runs, so callers that need the clear to finish first
///   (matching prior inline behavior) can rely on that ordering.
Future<T> confirmDemoOrder<T, V>({
  required V validation,
  required bool Function(V validation) isValid,
  required T Function(V validation) onInvalid,
  required Future<String?> Function() placeOrder,
  required String Function() fallbackOrderId,
  required T Function() onSaveFailed,
  required void Function(String orderId) recordActivity,
  required FutureOr<void> Function() clearCart,
  required T Function(String orderId) onConfirmed,
}) async {
  if (!isValid(validation)) {
    return onInvalid(validation);
  }

  String orderId;
  try {
    orderId = await placeOrder() ?? fallbackOrderId();
  } on Object {
    return onSaveFailed();
  }

  recordActivity(orderId);
  await clearCart();
  return onConfirmed(orderId);
}
