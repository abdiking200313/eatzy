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
///   to [fallbackOrder] to synthesize a demo order (matching prior behavior
///   for controllers without a real order repository configured).
/// - [onSaveFailed] builds the failure result to return if [placeOrder]
///   throws, given the caught error and stack trace so callers can log it
///   (and, where the error is actionable, surface something more specific
///   than a generic retry message). Mirrors [LoadableState.runLoad]'s
///   `onError` signature.
/// - [recordActivity] and [clearCart] run, in that order, once an order
///   ([R] -- e.g. a `PlacedOrder` carrying the RPC's authoritative id and
///   totals, see issue #60) is available, before [onConfirmed] builds the
///   success result. [clearCart] may return a `Future` (e.g. a cart backed
///   by persisted storage) or complete synchronously; either way it is
///   awaited before [onConfirmed] runs, so callers that need the clear to
///   finish first (matching prior inline behavior) can rely on that
///   ordering.
Future<T> confirmDemoOrder<T, V, R>({
  required V validation,
  required bool Function(V validation) isValid,
  required T Function(V validation) onInvalid,
  required Future<R?> Function() placeOrder,
  required R Function() fallbackOrder,
  required T Function(Object error, StackTrace stackTrace) onSaveFailed,
  required void Function(R order) recordActivity,
  required FutureOr<void> Function() clearCart,
  required T Function(R order) onConfirmed,
}) async {
  if (!isValid(validation)) {
    return onInvalid(validation);
  }

  R order;
  try {
    order = await placeOrder() ?? fallbackOrder();
  } on Object catch (error, stackTrace) {
    return onSaveFailed(error, stackTrace);
  }

  recordActivity(order);
  await clearCart();
  return onConfirmed(order);
}
