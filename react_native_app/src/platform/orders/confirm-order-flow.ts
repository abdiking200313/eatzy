/**
 * Ports `flutter_app/lib/services/shared/presentation/confirm_order_flow.dart`'s
 * `confirmDemoOrder` (issue #379): the shared "validate, place a demo order,
 * record activity, clear the cart" orchestration used by the grocery,
 * pharmacy, and food demo checkout flows.
 */

/**
 * Runs the common "validate, place a demo order, record activity, clear the
 * cart" shell shared by the grocery, pharmacy, and food demo checkout flows.
 *
 * The vertical-specific pieces are supplied by the caller:
 * - `validation` is the already-computed validation result.
 * - `isValid` reports whether `validation` passed.
 * - `onInvalid` builds the failure result to return when validation fails.
 * - `placeOrder` performs the repository call; a nullish result falls back
 *   to `fallbackOrder` to synthesize a demo order (matching prior behavior
 *   for controllers without a real order repository configured).
 * - `onSaveFailed` builds the failure result to return if `placeOrder`
 *   throws, given the caught error so callers can log it (and, where the
 *   error is actionable, surface something more specific than a generic
 *   retry message). TypeScript has no separate stack-trace parameter like
 *   the Dart original's `onSaveFailed(error, stackTrace)` -- the error
 *   itself is passed through, matching this codebase's other error-mapping
 *   convention (see `describeOrderSaveError` in `./order-errors`).
 * - `recordActivity` and `clearCart` run, in that order, once an order
 *   (`R` -- e.g. a `PlacedOrder` carrying the RPC's authoritative id and
 *   totals) is available, before `onConfirmed` builds the success result.
 *   `clearCart` may return a `Promise` (e.g. a cart backed by persisted
 *   storage) or complete synchronously; either way it is awaited before
 *   `onConfirmed` runs, so callers that need the clear to finish first
 *   (matching prior inline behavior) can rely on that ordering.
 */
export async function confirmDemoOrder<T, V, R>({
  validation,
  isValid,
  onInvalid,
  placeOrder,
  fallbackOrder,
  onSaveFailed,
  recordActivity,
  clearCart,
  onConfirmed,
}: {
  validation: V;
  isValid: (validation: V) => boolean;
  onInvalid: (validation: V) => T;
  placeOrder: () => Promise<R | null | undefined>;
  fallbackOrder: () => R;
  onSaveFailed: (error: unknown) => T;
  recordActivity: (order: R) => void;
  clearCart: () => void | Promise<void>;
  onConfirmed: (order: R) => T;
}): Promise<T> {
  if (!isValid(validation)) {
    return onInvalid(validation);
  }

  let order: R;
  try {
    order = (await placeOrder()) ?? fallbackOrder();
  } catch (error) {
    return onSaveFailed(error);
  }

  recordActivity(order);
  await clearCart();
  return onConfirmed(order);
}
