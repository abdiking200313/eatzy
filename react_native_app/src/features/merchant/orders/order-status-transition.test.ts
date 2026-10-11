/**
 * Ports `flutter_app/test/order_status_transition_client_test.dart` (issue
 * #409 / P9-04). Despite the Dart file's name there is no separate
 * "transition client" class: it tests that the client call sites -- the
 * order detail screen's advance/cancel buttons, which pick their target via
 * `nextForwardOrderStatus` / `canCancelOrder` and call
 * `MerchantOrdersController.advanceStatus` -- never even *attempt* a
 * transition the server would reject. Defense in depth only; the server's
 * `is_legal_order_status_transition` stays the real enforcement point.
 *
 * `LEGAL_TRANSITIONS` is transcribed independently from
 * `is_legal_order_status_transition` in
 * `supabase/migrations/20260830140000_add_order_status_transition_rpcs.sql`
 * -- deliberately NOT derived from `orderStatusFlow` / the helpers under
 * test, so a bug in that shared vocabulary can't also corrupt the oracle.
 */
import type { MerchantVertical } from '../store/api/merchant-vertical';
import { merchantOrderFromRow, type MerchantOrder } from './api/merchant-order';
import { canCancelOrder, MERCHANT_ORDER_VERTICAL_CONFIG, nextForwardOrderStatus } from './api/merchant-order-vertical';
import type { AdvanceOrderStatusInput, MerchantOrdersRepository } from './api/merchant-orders-repository';
import { MerchantOrdersController } from './merchant-orders-controller';

jest.mock('@/platform/supabase/client', () => ({ supabase: {} }));
jest.mock('@/platform/error-reporting/error-reporter', () => ({ ErrorReporting: { instance: { reportError: jest.fn() } } }));

type Transition = `${MerchantVertical}:${string}->${string}`;

const LEGAL_TRANSITIONS: ReadonlySet<Transition> = new Set<Transition>([
  'food:confirmed->preparing',
  'food:preparing->out_for_delivery',
  'food:out_for_delivery->delivered',
  'food:confirmed->cancelled',
  'food:preparing->cancelled',
  'grocery:confirmed->shopping',
  'grocery:shopping->out_for_delivery',
  'grocery:out_for_delivery->delivered',
  'grocery:confirmed->cancelled',
  'grocery:shopping->cancelled',
  'pharmacy:confirmed->packing',
  'pharmacy:packing->out_for_delivery',
  'pharmacy:out_for_delivery->delivered',
  'pharmacy:confirmed->cancelled',
  'pharmacy:packing->cancelled',
]);

function parse(transition: Transition): { vertical: MerchantVertical; from: string; to: string } {
  const [vertical, rest] = transition.split(':') as [MerchantVertical, string];
  const [from, to] = rest.split('->');
  return { vertical, from, to };
}

/** Every status value that appears anywhere in {@link LEGAL_TRANSITIONS}. */
const ALL_KNOWN_STATUSES = new Set([...LEGAL_TRANSITIONS].flatMap((t) => [parse(t).from, parse(t).to]));

const VERTICALS: readonly MerchantVertical[] = ['food', 'grocery', 'pharmacy'];

/**
 * Mirrors the Dart `_RecordingOrdersRepository`: records every
 * `(vertical, previous, new)` triple and always succeeds -- unlike
 * `FakeMerchantOrdersRepository` it does NOT re-validate transitions, so the
 * test proves the *caller* never asks for an illegal one.
 */
class RecordingOrdersRepository implements MerchantOrdersRepository {
  readonly calls: Transition[] = [];
  private readonly statusById = new Map<string, string>();

  seed(order: MerchantOrder): void {
    this.statusById.set(order.id, order.status);
  }
  async fetchOrders(): Promise<MerchantOrder[]> {
    return [];
  }
  async advanceOrderStatus({ vertical, orderId, newStatus }: AdvanceOrderStatusInput): Promise<string> {
    const previous = this.statusById.get(orderId)!;
    this.calls.push(`${vertical}:${previous}->${newStatus}`);
    this.statusById.set(orderId, newStatus);
    return newStatus;
  }
  watchOrders(): () => void {
    return () => {};
  }
}

function orderWith(vertical: MerchantVertical, status: string): MerchantOrder {
  return merchantOrderFromRow(
    { id: 'order-1', status, subtotal: 0, delivery_fee: 0, total: 0, recipient_name: '', phone: '', street: '', district: '', city: '' },
    vertical,
  );
}

async function attempt(vertical: MerchantVertical, status: string, target: string) {
  const repository = new RecordingOrdersRepository();
  const order = orderWith(vertical, status);
  repository.seed(order);
  const controller = new MerchantOrdersController({ repository, vertical, storeId: 'store-1' });
  const succeeded = await controller.advanceStatus(order, target);
  return { succeeded, calls: repository.calls };
}

describe('client call sites only ever request a legal status transition', () => {
  for (const vertical of VERTICALS) {
    // Every state actually reachable in this vertical's own forward vocabulary.
    const reachableStates = [...MERCHANT_ORDER_VERTICAL_CONFIG[vertical].orderStatusFlow, 'cancelled'];

    for (const status of reachableStates) {
      it(`${vertical}: advancing from "${status}" (if offered) is legal`, async () => {
        const nextStatus = nextForwardOrderStatus(vertical, status);
        // Matches the detail screen: no forward action once the flow is terminal.
        if (nextStatus == null) return;

        const { succeeded, calls } = await attempt(vertical, status, nextStatus);

        expect(succeeded).toBe(true);
        expect(calls).toHaveLength(1);
        expect(LEGAL_TRANSITIONS.has(calls[0])).toBe(true);
      });

      it(`${vertical}: cancelling from "${status}" (if offered) is legal`, async () => {
        // Matches the detail screen: no cancel/reject button when canCancelOrder is false.
        if (!canCancelOrder(vertical, status)) return;

        const { succeeded, calls } = await attempt(vertical, status, 'cancelled');

        expect(succeeded).toBe(true);
        expect(calls).toHaveLength(1);
        expect(LEGAL_TRANSITIONS.has(calls[0])).toBe(true);
      });
    }

    // The other direction: every transition the RPC accepts is something the
    // client vocabulary can actually offer from some reachable state.
    it(`${vertical}: every legal transition is reachable through the client vocabulary`, () => {
      const legalForVertical = [...LEGAL_TRANSITIONS].map(parse).filter((t) => t.vertical === vertical);
      expect(legalForVertical.length).toBeGreaterThan(0);
      for (const { from, to } of legalForVertical) {
        const viaAdvance = nextForwardOrderStatus(vertical, from) === to;
        const viaCancel = to === 'cancelled' && canCancelOrder(vertical, from);
        expect({ transition: `${vertical}:${from}->${to}`, reachable: viaAdvance || viaCancel }).toEqual({
          transition: `${vertical}:${from}->${to}`,
          reachable: true,
        });
      }
    });
  }

  it('no vertical ever offers a transition into an unrecognized status', () => {
    for (const vertical of VERTICALS) {
      for (const status of ALL_KNOWN_STATUSES) {
        const nextStatus = nextForwardOrderStatus(vertical, status);
        if (nextStatus != null) {
          expect(ALL_KNOWN_STATUSES.has(nextStatus)).toBe(true);
        }
      }
    }
  });

  it('RN-only: every advance RPC name matches the migration', () => {
    expect(VERTICALS.map((v) => MERCHANT_ORDER_VERTICAL_CONFIG[v].advanceOrderStatusRpc)).toEqual([
      'advance_food_order_status',
      'advance_grocery_order_status',
      'advance_pharmacy_order_status',
    ]);
  });
});
