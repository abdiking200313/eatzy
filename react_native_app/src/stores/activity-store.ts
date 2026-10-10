/**
 * Ports `flutter_app/lib/platform/activity/presentation/activity_controller.dart`
 * (`ActivityController`) as a Zustand store -- issue #397 / P8-01. The
 * unified activity feed for the food/grocery/pharmacy verticals.
 *
 * Differences from the Dart source, both additive:
 *  - `refreshOrder` re-reads one order's `customer_activity` row and
 *    `record`s it. The Activity tab calls it for every Realtime change on
 *    the user's order tables (see `watchCustomerOrders`), so a status change
 *    made in the database shows up without a manual refresh.
 *  - The store registers itself with `sessionResetRegistry`, the RN
 *    equivalent of Flutter's `AccountStateCoordinator` calling
 *    `ActivityController.resetSessionState()` directly on an owner change.
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';

import type { ActivityItem } from '@/platform/activity/api/activity-item';
import { fetchActivities, fetchOrderById } from '@/platform/activity/api/activity-repository';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import { sessionResetRegistry, type SessionResetRegistry } from './session-reset-registry';

/** Mirrors `ActivityController.load`'s generic user-facing error. */
export const ACTIVITY_LOAD_ERROR = 'Activity could not be loaded. Please try again.';

export interface ActivityState {
  /** Newest first. */
  items: ActivityItem[];
  isLoading: boolean;
  hasLoaded: boolean;
  loadError: string | null;
  /** Ports `ActivityController.load`: a no-op while a load is already running. */
  load: () => Promise<void>;
  /** Ports `ActivityController.record`: inserts or replaces by id, keeping newest first. */
  record: (item: ActivityItem) => void;
  /** Re-reads one order's row and records it; a row that's gone (or a failed fetch) leaves the list untouched. */
  refreshOrder: (options: { orderId: string; serviceId: string }) => Promise<void>;
  /** Ports `ActivityController.resetSessionState`. */
  resetSessionState: () => void;
}

export interface CreateActivityStoreOptions {
  /** Defaults to `fetchActivities()` against the real Supabase client. Mirrors the Dart `ActivityRepository` injection. */
  fetchActivities?: () => Promise<ActivityItem[]>;
  /** Defaults to `fetchOrderById` against the real Supabase client. */
  fetchOrder?: (options: { orderId: string; serviceId: string }) => Promise<ActivityItem | null>;
  /** Defaults to the shared `sessionResetRegistry` singleton -- pass a fresh one in a test. */
  registry?: SessionResetRegistry;
}

export interface ActivityStoreHandle {
  store: UseBoundStore<StoreApi<ActivityState>>;
  /** Stops listening for account changes. Mainly for tests. */
  unregister: () => void;
}

function sortNewestFirst(items: ActivityItem[]): ActivityItem[] {
  return [...items].sort((a, b) => b.occurredAt.getTime() - a.occurredAt.getTime());
}

function reportError(error: unknown, context: string) {
  ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);
}

/** Builds an independent activity store. Exists mainly so a test can build an isolated instance -- see {@link useActivityStore} for the app-wide one. */
export function createActivityStore(options: CreateActivityStoreOptions = {}): ActivityStoreHandle {
  const fetchAll = options.fetchActivities ?? (() => fetchActivities());
  const fetchOne = options.fetchOrder ?? ((order: { orderId: string; serviceId: string }) => fetchOrderById(order));
  const registry = options.registry ?? sessionResetRegistry;
  // Bumped on every reset so a load/refresh that started for the previous
  // account can't write its result into the next account's feed.
  let generation = 0;

  const store = create<ActivityState>((set, get) => ({
    items: [],
    isLoading: false,
    hasLoaded: false,
    loadError: null,

    load: async () => {
      if (get().isLoading) return;
      const startedAt = generation;
      set({ isLoading: true, loadError: null });
      try {
        const items = await fetchAll();
        if (startedAt !== generation) return;
        set({ items: sortNewestFirst(items), hasLoaded: true });
      } catch (error) {
        if (startedAt !== generation) return;
        set({ loadError: ACTIVITY_LOAD_ERROR });
        reportError(error, 'ActivityController.load');
      } finally {
        if (startedAt === generation) set({ isLoading: false });
      }
    },

    record: (item) => {
      set({ items: sortNewestFirst([...get().items.filter((existing) => existing.id !== item.id), item]) });
    },

    refreshOrder: async (order) => {
      const startedAt = generation;
      try {
        const item = await fetchOne(order);
        if (item != null && startedAt === generation) get().record(item);
      } catch (error) {
        reportError(error, 'ActivityStore.refreshOrder');
      }
    },

    resetSessionState: () => {
      generation++;
      set({ items: [], isLoading: false, hasLoaded: false, loadError: null });
    },
  }));

  const unregister = registry.register(() => store.getState().resetSessionState());
  return { store, unregister };
}

const defaultActivityStore = createActivityStore();

/** The app-wide activity feed store. */
export const useActivityStore = defaultActivityStore.store;
export const activityStore = defaultActivityStore;
