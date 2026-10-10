/**
 * Data half of `flutter_app/lib/features/orders/presentation/track_order_screen.dart`'s
 * `_TrackOrderScreenState` (issue #398 / P8-02): loads one of the customer's
 * own orders via `fetchOrderDetails`, and keeps a single Realtime
 * subscription (`watchOrder`) open while the order can still change.
 *
 * Mirrors the Dart lifecycle exactly:
 *  - nothing is loaded or watched without both an order id and a service id;
 *  - after every load (not only the first), a missing or final
 *    (`delivered`/`cancelled`) order stops the watch, and any other order
 *    starts it if it isn't already running -- ticks reuse the one
 *    subscription rather than resubscribing;
 *  - each tick is only a "something changed" ping that triggers a refetch;
 *  - the subscription is torn down on unmount (the Dart `dispose`).
 *
 * One deliberate difference from the Dart `FutureBuilder`: a refetch keeps
 * the already-loaded order on screen (`isRefreshing`) instead of swapping
 * the whole page for a spinner on every realtime tick or pull-to-refresh.
 */
import { useCallback, useEffect, useRef, useState } from 'react';

import { fetchOrderDetails, watchOrder } from './api/activity-repository';
import { isOrderFinal, type OrderDetails } from './api/order-details';

export interface OrderReference {
  orderId: string;
  serviceId: string;
}

export type FetchOrderDetails = (reference: OrderReference) => Promise<OrderDetails | null>;
/** Calls `onChange` on every server-side change to the order; returns a function that stops watching. */
export type WatchOrder = (reference: OrderReference, onChange: () => void) => () => void;

export interface UseOrderDetailsOptions {
  orderId?: string;
  serviceId?: string;
  /** Injectable for tests; defaults to the Supabase-backed `fetchOrderDetails`. */
  fetchDetails?: FetchOrderDetails;
  /** Injectable for tests; defaults to the Supabase Realtime-backed `watchOrder`. */
  watch?: WatchOrder;
}

export type OrderDetailsStatus = 'noReference' | 'loading' | 'error' | 'notFound' | 'loaded';

export interface UseOrderDetailsResult {
  status: OrderDetailsStatus;
  order: OrderDetails | null;
  /** True while a refetch runs with an order already on screen. */
  isRefreshing: boolean;
  /** Refetches (the Dart `_retry`); resolves once that load settles. */
  reload: () => Promise<void>;
}

const defaultFetch: FetchOrderDetails = (reference) => fetchOrderDetails(reference);
const defaultWatch: WatchOrder = (reference, onChange) => watchOrder(reference, onChange);

export function useOrderDetails({ orderId, serviceId, fetchDetails = defaultFetch, watch = defaultWatch }: UseOrderDetailsOptions): UseOrderDetailsResult {
  const hasReference = !!orderId && !!serviceId;
  const [loadStatus, setLoadStatus] = useState<Exclude<OrderDetailsStatus, 'noReference'>>('loading');
  const [order, setOrder] = useState<OrderDetails | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  // The current effect's `load`, so `reload` (and pull-to-refresh/retry)
  // refetch through the same subscription-owning closure.
  const reloadRef = useRef<() => Promise<void>>(async () => {});

  // `fetchDetails`/`watch` are expected to be stable (the module-level
  // defaults are); a new one restarts the load and subscription.
  useEffect(() => {
    if (!orderId || !serviceId) return;
    const reference = { orderId, serviceId };
    let active = true;
    let stopWatch: (() => void) | null = null;
    let hasOrder = false;
    // Only the newest load may write state: an older response landing late
    // must not overwrite a fresher one.
    let latestSeq = 0;

    const stopWatching = () => {
      stopWatch?.();
      stopWatch = null;
    };

    const load = async () => {
      const seq = ++latestSeq;
      if (hasOrder) setIsRefreshing(true);

      let next: OrderDetails | null;
      try {
        next = await fetchDetails(reference);
      } catch {
        if (!active || seq !== latestSeq) return;
        hasOrder = false;
        setOrder(null);
        setIsRefreshing(false);
        setLoadStatus('error');
        return;
      }
      if (!active || seq !== latestSeq) return;

      hasOrder = next != null;
      setOrder(next);
      setIsRefreshing(false);
      setLoadStatus(next == null ? 'notFound' : 'loaded');

      // Ports `_handleLoaded`.
      if (next == null || isOrderFinal(next)) {
        stopWatching();
      } else if (stopWatch == null) {
        stopWatch = watch(reference, () => void load());
      }
    };

    reloadRef.current = load;
    void load();
    return () => {
      active = false;
      stopWatching();
      reloadRef.current = async () => {};
    };
  }, [fetchDetails, orderId, serviceId, watch]);

  const reload = useCallback(() => reloadRef.current(), []);

  return { status: hasReference ? loadStatus : 'noReference', order: hasReference ? order : null, isRefreshing, reload };
}
