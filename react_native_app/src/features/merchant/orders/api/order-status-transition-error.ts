/**
 * Mirrors the Dart `OrderStatusTransitionException` (from
 * `merchant_orders_repository.dart`, issue #408 / P9-03): the server rejected
 * a status change (illegal transition, an order the caller doesn't manage, or
 * one that no longer exists). `message` is the RPC's own `raise exception`
 * text, surfaced verbatim so an illegal transition is a clear error.
 *
 * Kept in its own file, free of the Supabase client import, so test helpers
 * can throw it without loading env-dependent modules.
 */
export class OrderStatusTransitionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'OrderStatusTransitionError';
  }

  /** Mirrors the Dart `toString()` returning the raw message. */
  override toString(): string {
    return this.message;
  }
}
