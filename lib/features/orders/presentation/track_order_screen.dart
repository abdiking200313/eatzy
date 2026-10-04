import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_scope.dart';
import '../../../platform/activity/data/activity_repository.dart';
import '../../../platform/activity/data/order_again_repository.dart';
import '../../../platform/activity/models/order_details.dart';
import '../../../platform/activity/presentation/order_again_service.dart';
import '../../../platform/error_reporting/error_reporter.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import 'widgets/order_details_content.dart';
import 'widgets/track_order_message.dart';

/// The order details page for one of the customer's own orders, keyed by
/// [orderId]/[serviceId] (from the `/track-order/:serviceId/:orderId`
/// route, opened by tapping an order on the Activity tab or the home
/// screen's Recent activity). Shows the order's progress, its items and
/// charges, delivery address and payment, with an "Order again" action.
///
/// With no id/service — the bare `/track-order` route, e.g. an old deep
/// link — it renders a "no order selected" empty state instead of crashing
/// (see issue #43). There is still no courier assignment anywhere in the
/// schema (issue #80), so no courier card or ETA is shown.
class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({
    super.key,
    this.orderId,
    this.serviceId,
    this.repository,
    this.orderAgainService,
  });

  /// The `customer_activity` row id to look up. Null/empty means "no order
  /// selected".
  final String? orderId;

  /// The raw `service_id` this order belongs to (`food`, `grocery`, or
  /// `pharmacy`), used to scope the lookup alongside [orderId].
  final String? serviceId;

  /// Injectable for tests; defaults to a real Supabase-backed repository.
  final OrderDetailsRepository? repository;

  /// Injectable for tests; defaults to the app-wide carts.
  final OrderAgainService? orderAgainService;

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  Future<OrderDetails?>? _future;
  // Evaluated lazily on first access (only from `_orderAgainPressed`, a
  // button callback that never fires before this screen's first build), so
  // `AppScope.of(context)` is safe to call here -- see issue #283.
  late final OrderAgainService _orderAgain =
      widget.orderAgainService ??
      OrderAgainService(appServices: AppScope.of(context));
  bool _loadingReorder = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool get _hasOrderReference =>
      (widget.orderId?.isNotEmpty ?? false) &&
      (widget.serviceId?.isNotEmpty ?? false);

  OrderDetailsRepository get _repository =>
      widget.repository ??
      SupabaseActivityRepository(client: Supabase.instance.client);

  Future<OrderDetails?>? _load() {
    if (!_hasOrderReference) {
      return null;
    }
    return _repository.fetchOrderDetails(
      orderId: widget.orderId!,
      serviceId: widget.serviceId!,
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Order details',
      showBackButton: true,
      body: !_hasOrderReference
          ? const TrackOrderMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No order selected',
              message:
                  'Open an order from your Activity tab to see its '
                  'details here.',
            )
          : FutureBuilder<OrderDetails?>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return TrackOrderMessage(
                    icon: Icons.error_outline,
                    title: 'Order could not be loaded',
                    message: 'Please try again.',
                    actionLabel: 'Try again',
                    onAction: _retry,
                  );
                }
                final order = snapshot.data;
                if (order == null) {
                  return const TrackOrderMessage(
                    icon: Icons.search_off,
                    title: 'Order not found',
                    message:
                        "We couldn't find this order. It may not exist, "
                        'or it may belong to a different account.',
                  );
                }
                return OrderDetailsContent(
                  order: order,
                  onRefresh: () async {
                    _retry();
                    await _future;
                  },
                  orderAgainButton: OrderAgainService.canReorder(order.summary)
                      ? FilledButton.icon(
                          key: const ValueKey('order-details-order-again'),
                          onPressed: _loadingReorder
                              ? null
                              : () => _orderAgainPressed(order),
                          icon: _loadingReorder
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.replay_rounded),
                          label: const Text('Order again'),
                        )
                      : null,
                );
              },
            ),
    );
  }

  /// Loads the order's still-available items, asks before replacing a
  /// non-empty cart, fills the cart and opens it.
  Future<void> _orderAgainPressed(OrderDetails order) async {
    setState(() => _loadingReorder = true);
    ReorderBasket? basket;
    try {
      basket = await _orderAgain.loadBasket(order.summary);
    } on Object catch (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'TrackOrderScreen._orderAgainPressed',
      );
    }
    if (!mounted) return;
    setState(() => _loadingReorder = false);

    if (basket == null) {
      showCartSnackBar(context, 'This order could not be loaded. Try again.');
      return;
    }
    if (basket.isEmpty) {
      showCartSnackBar(
        context,
        'None of these items can be ordered right now.',
      );
      return;
    }
    if (_orderAgain.wouldReplaceCart(basket)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace your cart?'),
          content: const Text(
            'Your cart already has items. Ordering again will replace them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    final cartRoute = await _orderAgain.fillCart(basket);
    if (!mounted) return;
    if (basket.skippedNames.isNotEmpty) {
      showCartSnackBar(
        context,
        'No longer available: ${basket.skippedNames.join(', ')}',
      );
    }
    // `go`: each cart lives in its service's shell branch (issue #67).
    context.go(cartRoute);
  }
}
