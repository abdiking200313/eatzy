/**
 * Drives the Activity tab's data (issue #397 / P8-01): loads the feed for
 * the signed-in user (and again whenever the owner changes), and keeps a
 * Realtime subscription on that user's order tables open while mounted --
 * every change re-reads just that order's row (`refreshOrder`), so a
 * status change made in the database appears without a manual refresh.
 */
import { useEffect } from 'react';
import type { StoreApi, UseBoundStore } from 'zustand';

import type { ActivityState } from '@/stores/activity-store';

import { watchCustomerOrders, type CustomerOrderChange } from './api/activity-repository';

export interface UseActivityFeedOptions {
  store: UseBoundStore<StoreApi<ActivityState>>;
  /** `null` while signed out: nothing is loaded or watched. */
  userId: string | null;
  /** Injectable for tests; defaults to `watchCustomerOrders` on the real Supabase client. */
  watch?: (profileId: string, onChange: (change: CustomerOrderChange) => void) => () => void;
}

const defaultWatch = (profileId: string, onChange: (change: CustomerOrderChange) => void) => watchCustomerOrders(profileId, onChange);

export function useActivityFeed({ store, userId, watch = defaultWatch }: UseActivityFeedOptions): void {
  useEffect(() => {
    if (userId == null) return;
    void store.getState().load();
  }, [store, userId]);

  useEffect(() => {
    if (userId == null) return;
    return watch(userId, (change) => {
      void store.getState().refreshOrder({ orderId: change.orderId, serviceId: change.serviceId });
    });
  }, [store, userId, watch]);
}
