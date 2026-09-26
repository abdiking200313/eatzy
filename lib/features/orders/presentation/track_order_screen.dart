import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/theme.dart';
import '../../../platform/activity/data/activity_repository.dart';
import '../../../platform/activity/data/order_again_repository.dart';
import '../../../platform/activity/models/order_details.dart';
import '../../../platform/activity/presentation/order_again_service.dart';
import '../../../platform/error_reporting/error_reporter.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';

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
  late final OrderAgainService _orderAgain =
      widget.orderAgainService ?? OrderAgainService();
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
          ? const _TrackOrderMessage(
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
                  return _TrackOrderMessage(
                    icon: Icons.error_outline,
                    title: 'Order could not be loaded',
                    message: 'Please try again.',
                    actionLabel: 'Try again',
                    onAction: _retry,
                  );
                }
                final order = snapshot.data;
                if (order == null) {
                  return const _TrackOrderMessage(
                    icon: Icons.search_off,
                    title: 'Order not found',
                    message:
                        "We couldn't find this order. It may not exist, "
                        'or it may belong to a different account.',
                  );
                }
                return _OrderDetailsContent(
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

class _OrderDetailsContent extends StatelessWidget {
  const _OrderDetailsContent({
    required this.order,
    required this.onRefresh,
    this.orderAgainButton,
  });

  final OrderDetails order;
  final Future<void> Function() onRefresh;
  final Widget? orderAgainButton;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final summary = order.summary;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          TwSpacing.x5,
          TwSpacing.x5,
          TwSpacing.x5,
          TwSpacing.x6,
        ),
        children: [
          OutlinedCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.storeName ?? summary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TwText.fontBoldBase,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Order #${_shortId(order.id)}',
                        style: TwText.textXs.copyWith(
                          color: TwColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat(
                          'MMM d, yyyy · h:mm a',
                        ).format(summary.occurredAt.toLocal()),
                        style: TwText.textXs.copyWith(
                          color: TwColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TwSpacing.x2),
                StatusPill(
                  label: orderStatusLabel(order.status),
                  backgroundColor: palette.soft,
                  foregroundColor: palette.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: TwSpacing.sectionGap),
          _TrackingCard(order: order),
          const SizedBox(height: TwSpacing.sectionGap),
          _ItemsCard(order: order),
          if (_hasDeliveryInfo(order)) ...[
            const SizedBox(height: TwSpacing.sectionGap),
            _DeliveryCard(order: order),
          ],
          if (summary.paymentMethodLabel case final methodLabel?) ...[
            const SizedBox(height: TwSpacing.sectionGap),
            OutlinedCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment', style: TwText.fontBoldSm),
                        const SizedBox(height: TwSpacing.x2),
                        Text(methodLabel, style: TwText.textSm),
                      ],
                    ),
                  ),
                  if (summary.paymentStatusLabel case final statusLabel?)
                    StatusPill(
                      label: statusLabel,
                      backgroundColor: palette.soft,
                      foregroundColor: palette.accent,
                    ),
                ],
              ),
            ),
          ],
          if (orderAgainButton case final button?) ...[
            const SizedBox(height: TwSpacing.x6),
            SizedBox(width: double.infinity, child: button),
          ],
        ],
      ),
    );
  }

  static bool _hasDeliveryInfo(OrderDetails order) =>
      order.addressLine != null ||
      order.recipientName != null ||
      order.phone != null ||
      order.deliveryNote != null;

  /// UUID order ids are unreadable in full; the first block is enough to
  /// quote to support.
  static String _shortId(String id) {
    final head = id.split('-').first;
    return head.length >= 6 ? head.toUpperCase() : id;
  }
}

/// Order progress through the vertical's real status flow (issue #131's
/// `advance_*_order_status` RPCs move an order along it).
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    final List<_TimelineStep> steps;
    if (order.isCancelled) {
      steps = const [
        _TimelineStep(
          label: 'Order cancelled',
          isCompleted: true,
          hasConnector: false,
        ),
      ];
    } else if (order.statusStep < 0) {
      // A status this client doesn't know: show it as-is rather than
      // guessing where it sits in the flow.
      steps = [
        _TimelineStep(
          label: orderStatusLabel(order.status),
          isCompleted: true,
          hasConnector: false,
        ),
      ];
    } else {
      final flow = order.statusFlow;
      steps = [
        for (var i = 0; i < flow.length; i++)
          _TimelineStep(
            label: orderStatusLabel(flow[i]),
            isCompleted: i <= order.statusStep,
            hasConnector: i < flow.length - 1,
          ),
      ];
    }
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track order', style: TwText.fontBoldSm),
          const SizedBox(height: TwSpacing.x4),
          for (final step in steps) _TimelineStepRow(step: step),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    final tax = order.tax;
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items', style: TwText.fontBoldSm),
          const SizedBox(height: TwSpacing.x3),
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: TwSpacing.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      line.quantityLabel,
                      style: TwText.fontBoldSm.copyWith(
                        color: TwColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(child: Text(line.name, style: TwText.textSm)),
                  const SizedBox(width: TwSpacing.x2),
                  Text(
                    AppMoney.formatCents(line.lineTotal),
                    style: TwText.textSm,
                  ),
                ],
              ),
            ),
          const Divider(height: TwSpacing.x5),
          _AmountRow(label: 'Subtotal', cents: order.subtotal),
          _AmountRow(label: 'Delivery fee', cents: order.deliveryFee),
          if (tax != null && tax > 0) _AmountRow(label: 'Tax', cents: tax),
          const SizedBox(height: TwSpacing.x1),
          _AmountRow(label: 'Total', cents: order.total, emphasize: true),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.cents,
    this.emphasize = false,
  });

  final String label;
  final int cents;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? TwText.fontBoldBase
        : TwText.textSm.copyWith(color: TwColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(AppMoney.formatCents(cents), style: style),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    final muted = TwText.textSm.copyWith(color: TwColors.textMuted);
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery address', style: TwText.fontBoldSm),
          const SizedBox(height: TwSpacing.x2),
          if (order.recipientName case final name?)
            Text(name, style: TwText.textSm),
          if (order.addressLine case final address?)
            Text(address, style: TwText.textSm),
          if (order.phone case final phone?) Text(phone, style: muted),
          if (order.deliveryNote case final note?) ...[
            const SizedBox(height: TwSpacing.x2),
            Text(note, style: muted),
          ],
        ],
      ),
    );
  }
}

class _TrackOrderMessage extends StatelessWidget {
  const _TrackOrderMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TwColors.textMuted, size: 48),
            const SizedBox(height: TwSpacing.x3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TwText.fontBoldBase,
            ),
            const SizedBox(height: TwSpacing.x2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TwText.textSm.copyWith(color: TwColors.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: TwSpacing.x4),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineStepRow extends StatelessWidget {
  const _TimelineStepRow({required this.step});

  final _TimelineStep step;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: TwSpacing.x5,
              height: TwSpacing.x5,
              decoration: BoxDecoration(
                color: step.isCompleted
                    ? palette.accent
                    : TwColors.borderStrong,
                borderRadius: BorderRadius.circular(TwRadius.full),
              ),
              child: step.isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (step.hasConnector)
              Container(
                width: 2,
                height: TwSpacing.x6,
                color: step.isCompleted
                    ? palette.accent
                    : TwColors.borderStrong,
              ),
          ],
        ),
        const SizedBox(width: TwSpacing.x4),
        Expanded(
          child: Text(
            step.label,
            style: TwText.fontBoldSm.copyWith(
              color: step.isCompleted ? TwColors.text : TwColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.label,
    required this.isCompleted,
    required this.hasConnector,
  });

  final String label;
  final bool isCompleted;
  final bool hasConnector;
}
