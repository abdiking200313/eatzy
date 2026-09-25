import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../../error_reporting/error_reporter.dart';
import '../../localization/app_money.dart';
import '../data/order_again_repository.dart';
import '../models/activity_item.dart';
import 'activity_controller.dart';
import 'order_again_service.dart';

/// Maps [ServiceId] back to the raw `service_id` path segment
/// `trackOrderDetailsPath` expects. Returns `null` for [ServiceId.unknown]:
/// [ActivityItem.fromMap] already discards the original raw string for any
/// service it doesn't recognize (see #62), so there's nothing real to key a
/// track-order lookup on — the row hides its "Track order" action instead
/// of linking to an order that can never resolve.
String? _trackableServiceId(ServiceId serviceId) => switch (serviceId) {
  ServiceId.food => 'food',
  ServiceId.grocery => 'grocery',
  ServiceId.pharmacy => 'pharmacy',
  ServiceId.unknown => null,
};

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({
    super.key,
    this.controller,
    this.orderAgainService,
    this.title = 'Activity',
  });

  final ActivityController? controller;
  final OrderAgainService? orderAgainService;
  final String title;

  @override
  Widget build(BuildContext context) {
    final activityController = controller ?? ActivityController.instance;
    final orderAgain = orderAgainService ?? OrderAgainService();

    return AppScaffold(
      title: title,
      body: AnimatedBuilder(
        animation: activityController,
        builder: (context, _) {
          final items = activityController.items;
          if (activityController.isLoading && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (activityController.loadError case final error?
              when items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(TwSpacing.x8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: TwSpacing.x4),
                    FilledButton(
                      onPressed: activityController.load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: activityController.load,
            child: items.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: const [
                      SliverFillRemaining(child: _EmptyActivity()),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(TwSpacing.x5),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _ActivityListCard(items: items, orderAgain: orderAgain),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: TwColors.textMuted,
              size: 48,
            ),
            SizedBox(height: TwSpacing.x3),
            Text(
              'No activity yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: TwSpacing.x2),
            Text(
              'Your orders and bookings will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TwColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The activity feed as a single white card containing every record, with
/// internal dividers between rows ("one card per list, not one card per
/// row" — see #21/#27). Per-service accent stays confined to each row's
/// [ServiceIconChip]; the card itself always stays on [TwColors.card].
class _ActivityListCard extends StatelessWidget {
  const _ActivityListCard({required this.items, required this.orderAgain});

  final List<ActivityItem> items;
  final OrderAgainService orderAgain;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in items) ...[
            _ActivityRow(item: item, orderAgain: orderAgain),
            if (item != items.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatefulWidget {
  const _ActivityRow({required this.item, required this.orderAgain});

  final ActivityItem item;
  final OrderAgainService orderAgain;

  @override
  State<_ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<_ActivityRow> {
  bool _loadingReorder = false;

  ActivityItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final module = ServiceRegistry.byId(item.serviceId);
    final colors = ServiceThemes.forId(item.serviceId);
    final trackableServiceId = _trackableServiceId(item.serviceId);
    return InkWell(
      // `go`, not `push` — detailsRoute is always a service vertical's shell
      // branch root (see app_router.dart); switch to it within the shell
      // instead of stacking a route over the nav bar (issue #67).
      onTap: item.detailsRoute.isEmpty
          ? null
          : () => context.go(item.detailsRoute),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TwSpacing.x4,
          vertical: TwSpacing.rhythmDefault,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ServiceIconChip(
              icon: module.icon,
              background: colors.accent,
              foreground: colors.onAccent,
            ),
            const SizedBox(width: TwSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TwText.fontBoldSm),
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TwSpacing.x2,
                    runSpacing: TwSpacing.rhythmTight,
                    children: [
                      if (item.subtitle?.isNotEmpty == true)
                        Text(
                          item.subtitle!,
                          style: TwText.textXs.copyWith(
                            color: TwColors.textMuted,
                          ),
                        ),
                      StatusPill(
                        label: item.status,
                        backgroundColor: colors.soft,
                        foregroundColor: colors.accent,
                      ),
                    ],
                  ),
                  if (OrderAgainService.canReorder(item)) ...[
                    const SizedBox(height: TwSpacing.rhythmTight),
                    TextButton.icon(
                      key: ValueKey('order-again-${item.id}'),
                      onPressed: _loadingReorder ? null : _orderAgain,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: _loadingReorder
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Order again'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: TwSpacing.x2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppMoney.formatCents(item.amount),
                  style: TwText.fontBoldSm.copyWith(color: colors.accent),
                ),
                // Additive next to the row's own tap-to-shell-home behavior
                // above (issue #67) — this is the only way to reach a real,
                // order-keyed TrackOrderScreen (issue #43).
                if (trackableServiceId != null) ...[
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Tooltip(
                    message: 'Track order',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(TwRadius.full),
                      onTap: () => context.push(
                        AppRoutes.trackOrderDetailsPath(
                          serviceId: trackableServiceId,
                          orderId: item.id,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(TwSpacing.x1),
                        child: Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Loads the order's still-available items, asks before replacing a
  /// non-empty cart, fills the cart and opens it.
  Future<void> _orderAgain() async {
    setState(() => _loadingReorder = true);
    ReorderBasket? basket;
    try {
      basket = await widget.orderAgain.loadBasket(item);
    } on Object catch (error, stack) {
      ErrorReporting.instance.reportError(
        error,
        stack,
        context: 'ActivityScreen._orderAgain',
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
    if (widget.orderAgain.wouldReplaceCart(basket)) {
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

    final cartRoute = await widget.orderAgain.fillCart(basket);
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
