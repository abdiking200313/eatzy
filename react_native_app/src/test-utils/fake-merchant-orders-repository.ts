/**
 * Ports `flutter_app/test/helpers/fake_merchant_repositories.dart`'s
 * `FakeMerchantOrdersRepository` (issue #408 / P9-03): an in-memory
 * `MerchantOrdersRepository` that enforces the same legal-transition rules
 * as `is_legal_order_status_transition`, plus a fake realtime feed
 * ({@link FakeMerchantOrdersRepository.emitChange}) standing in for the
 * Supabase channel.
 */
import type { MerchantOrder } from '@/features/merchant/orders/api/merchant-order';
import { MERCHANT_ORDER_VERTICAL_CONFIG } from '@/features/merchant/orders/api/merchant-order-vertical';
import type {
  AdvanceOrderStatusInput,
  FetchMerchantOrdersInput,
  MerchantOrdersRepository,
} from '@/features/merchant/orders/api/merchant-orders-repository';
import { OrderStatusTransitionError } from '@/features/merchant/orders/api/order-status-transition-error';
import type { MerchantVertical } from '@/features/merchant/store/api/merchant-vertical';

export class FakeMerchantOrdersRepository implements MerchantOrdersRepository {
  orders: MerchantOrder[];

  /** When set, every fetch/advance call throws this instead of succeeding. */
  failureToThrow: unknown = null;

  /** Every `fetchOrders` call's input, in order. */
  readonly fetches: FetchMerchantOrdersInput[] = [];

  /** Active realtime watchers (removed when their stop function is called). */
  readonly watchers = new Set<{ input: FetchMerchantOrdersInput; onChange: () => void }>();

  constructor({ initialOrders = [] }: { initialOrders?: MerchantOrder[] } = {}) {
    this.orders = [...initialOrders];
  }

  async fetchOrders(input: FetchMerchantOrdersInput): Promise<MerchantOrder[]> {
    this.fetches.push(input);
    this.throwIfFailing();
    return [...this.orders];
  }

  async advanceOrderStatus({ vertical, orderId, newStatus }: AdvanceOrderStatusInput): Promise<string> {
    this.throwIfFailing();
    const index = this.orders.findIndex((order) => order.id === orderId);
    if (index === -1) throw new OrderStatusTransitionError('Order not found');
    const current = this.orders[index];
    if (!isLegalTransition(vertical, current.status, newStatus)) {
      throw new OrderStatusTransitionError(`Illegal ${vertical} order status transition: ${current.status} -> ${newStatus}`);
    }
    this.orders[index] = { ...current, status: newStatus };
    return newStatus;
  }

  watchOrders(input: FetchMerchantOrdersInput, onChange: () => void): () => void {
    const watcher = { input, onChange };
    this.watchers.add(watcher);
    return () => {
      this.watchers.delete(watcher);
    };
  }

  /** Simulates a realtime event: optionally prepends a newly placed order, then notifies every watcher. */
  emitChange(newOrder?: MerchantOrder): void {
    if (newOrder) this.orders = [newOrder, ...this.orders];
    for (const watcher of [...this.watchers]) watcher.onChange();
  }

  private throwIfFailing(): void {
    if (this.failureToThrow != null) throw this.failureToThrow;
  }
}

function isLegalTransition(vertical: MerchantVertical, from: string, to: string): boolean {
  const flow = MERCHANT_ORDER_VERTICAL_CONFIG[vertical].orderStatusFlow;
  const fromIndex = flow.indexOf(from);
  if (to === 'cancelled') return fromIndex === 0 || fromIndex === 1;
  const toIndex = flow.indexOf(to);
  return fromIndex !== -1 && toIndex === fromIndex + 1;
}
