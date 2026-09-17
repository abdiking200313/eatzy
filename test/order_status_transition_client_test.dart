import 'package:chowflow/features/merchant/orders/data/merchant_orders_repository.dart';
import 'package:chowflow/features/merchant/orders/models/merchant_order.dart';
import 'package:chowflow/features/merchant/orders/models/merchant_order_vertical.dart';
import 'package:chowflow/features/merchant/orders/presentation/merchant_orders_controller.dart';
import 'package:chowflow/features/merchant/store/models/merchant_vertical.dart';
import 'package:flutter_test/flutter_test.dart';

/// This test (ported from `merchant_app`, originally issue #135's third
/// acceptance bullet, unified into the main app by issue #232) fills a real
/// gap left by the other merchant test suites
/// (`merchant_orders_controller_test.dart`, `order_detail_screen_test.dart`,
/// `orders_screen_test.dart`): those all test the *error-handling path* --
/// what happens when something (the fake standing in for the RPC) rejects a
/// status change -- by handing the controller a status value the real UI
/// would never produce (e.g. `confirmed -> out_for_delivery` directly).
/// None of them assert the converse: that the client's own call sites
/// (`OrderDetailScreen`'s "advance"/"cancel" buttons, which decide their
/// target status via `nextForwardOrderStatus`/`canCancelOrder`) never even
/// *attempt* an illegal transition in the first place. That is what this
/// file tests, as defense in depth -- not a substitute for the server-side
/// check in `is_legal_order_status_transition` (issue #131), which remains
/// the real enforcement point.
///
/// [_legalTransitions] is transcribed independently from
/// `is_legal_order_status_transition` in
/// `supabase/migrations/20260830140000_add_order_status_transition_rpcs.sql`
/// -- deliberately NOT derived from `MerchantOrderVerticalConfig.orderStatusFlow`
/// / `nextForwardOrderStatus` / `canCancelOrder` (the very functions under
/// test), so a bug that corrupted that shared vocabulary would not also
/// corrupt the oracle checking it.
const Set<(String vertical, String from, String to)> _legalTransitions = {
  ('food', 'confirmed', 'preparing'),
  ('food', 'preparing', 'out_for_delivery'),
  ('food', 'out_for_delivery', 'delivered'),
  ('food', 'confirmed', 'cancelled'),
  ('food', 'preparing', 'cancelled'),
  ('grocery', 'confirmed', 'shopping'),
  ('grocery', 'shopping', 'out_for_delivery'),
  ('grocery', 'out_for_delivery', 'delivered'),
  ('grocery', 'confirmed', 'cancelled'),
  ('grocery', 'shopping', 'cancelled'),
  ('pharmacy', 'confirmed', 'packing'),
  ('pharmacy', 'packing', 'out_for_delivery'),
  ('pharmacy', 'out_for_delivery', 'delivered'),
  ('pharmacy', 'confirmed', 'cancelled'),
  ('pharmacy', 'packing', 'cancelled'),
};

/// Every status value that appears anywhere in [_legalTransitions], used to
/// probe statuses the client-side vocabulary might (incorrectly) invent.
final Set<String> _allKnownStatuses = {
  for (final transition in _legalTransitions) transition.$2,
  for (final transition in _legalTransitions) transition.$3,
};

/// Records every `(vertical, previousStatus, newStatus)` triple a caller
/// asks it to advance to, and always succeeds -- unlike
/// `FakeMerchantOrdersRepository` in `test/helpers/fake_merchant_repositories.dart`,
/// this repository does NOT re-implement the legal-transition check itself.
/// The whole point of this test is to prove the *caller* (the controller,
/// driven exactly the way `OrderDetailScreen` drives it) never even attempts
/// an illegal call -- re-validating server-side here would test the fake, not
/// the client.
class _RecordingOrdersRepository implements MerchantOrdersRepository {
  final List<(String vertical, String from, String to)> calls = [];
  final Map<String, String> _statusById = {};

  void seed(MerchantOrder order) => _statusById[order.id] = order.status;

  @override
  Future<List<MerchantOrder>> fetchOrders({
    required MerchantVertical vertical,
    required String storeId,
  }) async => const [];

  @override
  Future<String> advanceOrderStatus({
    required MerchantVertical vertical,
    required String orderId,
    required String newStatus,
  }) async {
    final previous = _statusById[orderId]!;
    calls.add((vertical.name, previous, newStatus));
    _statusById[orderId] = newStatus;
    return newStatus;
  }
}

MerchantOrder _orderWith(MerchantVertical vertical, String status) {
  return MerchantOrder.fromMap({
    'id': 'order-1',
    'status': status,
    'subtotal': 0,
    'delivery_fee': 0,
    'total': 0,
    'recipient_name': '',
    'phone': '',
    'street': '',
    'district': '',
    'city': '',
  }, vertical: vertical);
}

void main() {
  group('client call sites only ever request a legal status transition', () {
    for (final vertical in MerchantVertical.values) {
      // Every state actually reachable in this vertical's own forward
      // vocabulary, per the real production source of truth.
      final reachableStates = [...vertical.orderStatusFlow, 'cancelled'];

      for (final status in reachableStates) {
        test(
          '${vertical.name}: advancing from "$status" (if offered) is legal',
          () async {
            final nextStatus = nextForwardOrderStatus(vertical, status);
            if (nextStatus == null) {
              // Matches `OrderDetailScreen`: no forward action is offered
              // once the flow's terminal state is reached, so there is
              // nothing a call site could illegally send.
              return;
            }

            final repository = _RecordingOrdersRepository();
            final order = _orderWith(vertical, status);
            repository.seed(order);
            final controller = MerchantOrdersController(
              repository: repository,
              vertical: vertical,
              storeId: 'store-1',
            );

            final succeeded = await controller.advanceStatus(order, nextStatus);

            expect(succeeded, isTrue);
            expect(repository.calls, hasLength(1));
            expect(
              _legalTransitions,
              contains(repository.calls.single),
              reason:
                  'nextForwardOrderStatus(${vertical.name}, "$status") '
                  'produced "$nextStatus", which '
                  'is_legal_order_status_transition would reject -- the '
                  '"advance" call site is not defense-in-depth safe.',
            );
          },
        );

        test(
          '${vertical.name}: cancelling from "$status" (if offered) is legal',
          () async {
            if (!canCancelOrder(vertical, status)) {
              // Matches `OrderDetailScreen`: no cancel/reject button is
              // rendered once `canCancelOrder` is false, so there is
              // nothing a call site could illegally send.
              return;
            }

            final repository = _RecordingOrdersRepository();
            final order = _orderWith(vertical, status);
            repository.seed(order);
            final controller = MerchantOrdersController(
              repository: repository,
              vertical: vertical,
              storeId: 'store-1',
            );

            final succeeded = await controller.advanceStatus(
              order,
              'cancelled',
            );

            expect(succeeded, isTrue);
            expect(repository.calls, hasLength(1));
            expect(
              _legalTransitions,
              contains(repository.calls.single),
              reason:
                  'canCancelOrder(${vertical.name}, "$status") is true, but '
                  'is_legal_order_status_transition would reject '
                  '"$status" -> "cancelled" -- the "cancel" call site is '
                  'not defense-in-depth safe.',
            );
          },
        );
      }

      // Cross-check in the other direction: every (from, to) pair this
      // vertical's real RPC would accept from the *initial* status must be
      // something `nextForwardOrderStatus`/`canCancelOrder` are actually
      // capable of offering from at least one reachable state -- i.e. the
      // client vocabulary is not missing a legal transition either (which
      // would itself be a product bug, just not one that risks calling the
      // RPC illegally).
      test('${vertical.name}: every legal transition is reachable through '
          'the client vocabulary', () {
        final legalForVertical = _legalTransitions.where(
          (transition) => transition.$1 == vertical.name,
        );
        for (final transition in legalForVertical) {
          final reachableViaAdvance =
              nextForwardOrderStatus(vertical, transition.$2) == transition.$3;
          final reachableViaCancel =
              transition.$3 == 'cancelled' &&
              canCancelOrder(vertical, transition.$2);
          expect(
            reachableViaAdvance || reachableViaCancel,
            isTrue,
            reason:
                '${transition.$1} ${transition.$2} -> ${transition.$3} is '
                'legal per the RPC migration but no client call site '
                'would ever produce it.',
          );
        }
      });
    }

    test(
      'no vertical ever offers a transition into an unrecognized status',
      () {
        for (final vertical in MerchantVertical.values) {
          for (final status in _allKnownStatuses) {
            final nextStatus = nextForwardOrderStatus(vertical, status);
            if (nextStatus != null) {
              expect(_allKnownStatuses, contains(nextStatus));
            }
          }
        }
      },
    );
  });
}
