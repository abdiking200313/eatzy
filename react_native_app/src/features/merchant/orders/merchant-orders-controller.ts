/**
 * Ports `flutter_app/lib/features/merchant/orders/presentation/merchant_orders_controller.dart`
 * (issue #408 / P9-03): load/advance-status bookkeeping for the "Orders"
 * screen, following `../store/merchant-store-controller.ts`'s pattern -- the
 * Dart `ChangeNotifier` (+ `LoadableState`/`SavableState`) becomes a plain
 * class with `subscribe`/`getSnapshot`, read through `useSyncExternalStore`.
 *
 * RN addition: {@link MerchantOrdersController.watch} subscribes to the
 * repository's realtime feed and reloads on every change, so a new customer
 * order appears without a manual refresh. Overlapping loads (a burst of
 * events, or a pull-to-refresh racing an event) are sequenced so only the
 * latest one's result is applied.
 */
import { useSyncExternalStore } from 'react';

import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import type { MerchantVertical } from '../store/api/merchant-vertical';
import type { MerchantOrder } from './api/merchant-order';
import { SupabaseMerchantOrdersRepository, type MerchantOrdersRepository } from './api/merchant-orders-repository';
import { OrderStatusTransitionError } from './api/order-status-transition-error';

export const ORDERS_LOAD_FAILURE_MESSAGE = 'Your orders could not be loaded. Please try again.';
export const ORDER_STATUS_FAILURE_MESSAGE = 'The order status could not be updated. Please try again.';

export interface MerchantOrdersState {
  orders: readonly MerchantOrder[];
  /** Whether {@link MerchantOrdersController.load} has completed successfully at least once (the empty state needs this). */
  hasLoaded: boolean;
  isLoading: boolean;
  loadError: string | null;
  isSaving: boolean;
  saveError: string | null;
}

const INITIAL_STATE: MerchantOrdersState = {
  orders: [],
  hasLoaded: false,
  isLoading: false,
  loadError: null,
  isSaving: false,
  saveError: null,
};

function report(error: unknown, context: string): void {
  ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);
}

export interface MerchantOrdersControllerOptions {
  vertical: MerchantVertical;
  storeId: string;
  repository?: MerchantOrdersRepository;
}

export class MerchantOrdersController {
  readonly vertical: MerchantVertical;
  readonly storeId: string;
  private readonly repository: MerchantOrdersRepository;
  private state: MerchantOrdersState = INITIAL_STATE;
  private readonly listeners = new Set<() => void>();
  private loadSequence = 0;

  constructor({ vertical, storeId, repository = new SupabaseMerchantOrdersRepository() }: MerchantOrdersControllerOptions) {
    this.vertical = vertical;
    this.storeId = storeId;
    this.repository = repository;
  }

  get orders(): readonly MerchantOrder[] {
    return this.state.orders;
  }
  get hasLoaded(): boolean {
    return this.state.hasLoaded;
  }
  get isLoading(): boolean {
    return this.state.isLoading;
  }
  get loadError(): string | null {
    return this.state.loadError;
  }
  get isSaving(): boolean {
    return this.state.isSaving;
  }
  get saveError(): string | null {
    return this.state.saveError;
  }

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  getSnapshot = (): MerchantOrdersState => this.state;

  async load(): Promise<void> {
    const sequence = ++this.loadSequence;
    this.setState({ isLoading: true, loadError: null });
    try {
      const orders = await this.repository.fetchOrders({ vertical: this.vertical, storeId: this.storeId });
      if (sequence !== this.loadSequence) return;
      this.setState({ orders, hasLoaded: true, isLoading: false });
    } catch (error) {
      report(error, 'MerchantOrdersController.load');
      if (sequence !== this.loadSequence) return;
      this.setState({ isLoading: false, loadError: ORDERS_LOAD_FAILURE_MESSAGE });
    }
  }

  /**
   * Advances `order` to `newStatus` via the vertical's
   * `advance_*_order_status` RPC. Resolves `true` on success; on failure
   * `saveError` carries the server's own rejection message for an
   * {@link OrderStatusTransitionError}, or a generic message otherwise.
   */
  async advanceStatus(order: MerchantOrder, newStatus: string): Promise<boolean> {
    this.setState({ isSaving: true, saveError: null });
    try {
      const updatedStatus = await this.repository.advanceOrderStatus({
        vertical: this.vertical,
        orderId: order.id,
        newStatus,
      });
      this.setState({
        orders: this.state.orders.map((existing) => (existing.id === order.id ? { ...existing, status: updatedStatus } : existing)),
        isSaving: false,
      });
      return true;
    } catch (error) {
      report(error, 'MerchantOrdersController.advanceStatus');
      this.setState({
        isSaving: false,
        saveError: error instanceof OrderStatusTransitionError ? error.message : ORDER_STATUS_FAILURE_MESSAGE,
      });
      return false;
    }
  }

  /** The current copy of `orderId` from {@link orders}, or `null` if it's not in the loaded list. */
  orderById(orderId: string): MerchantOrder | null {
    return this.state.orders.find((order) => order.id === orderId) ?? null;
  }

  /**
   * RN-only: reloads whenever the repository reports a change to this
   * store's orders. Returns a function that stops watching.
   */
  watch(): () => void {
    return this.repository.watchOrders({ vertical: this.vertical, storeId: this.storeId }, () => {
      void this.load();
    });
  }

  private setState(patch: Partial<MerchantOrdersState>): void {
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener();
  }
}

/** Subscribes a component to `controller`'s state. */
export function useMerchantOrdersState(controller: MerchantOrdersController): MerchantOrdersState {
  return useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
}
