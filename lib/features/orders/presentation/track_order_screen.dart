import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/theme.dart';
import '../../../platform/activity/data/activity_repository.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';

/// Shows a single real order's status, keyed by [orderId]/[serviceId] (from
/// the `/track-order/:serviceId/:orderId` route, reached via the "Track
/// order" action on an `ActivityScreen` row). With no id/service — the bare
/// `/track-order` route, e.g. an old deep link — it renders a "no order
/// selected" empty state instead of crashing (see issue #43).
///
/// Order status only ever has one real value today: nothing in this app
/// updates an order's status after creation (see issue #79 — a real
/// status-transition RPC is tracked separately in issue #131, not merged
/// yet), and there is no courier/delivery-partner assignment linked to any
/// order anywhere in the schema (see issue #80). So this screen shows the
/// one known status as a single completed step and says plainly that live
/// progress updates and delivery-partner details aren't available yet,
/// rather than fabricating a multi-step timeline, an ETA, or a courier
/// card.
class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({
    super.key,
    this.orderId,
    this.serviceId,
    this.repository,
  });

  /// The `customer_activity` row id to look up. Null/empty means "no order
  /// selected".
  final String? orderId;

  /// The raw `service_id` this order belongs to (`food`, `grocery`, or
  /// `pharmacy`), used to scope the lookup alongside [orderId].
  final String? serviceId;

  /// Injectable for tests; defaults to a real Supabase-backed repository.
  final OrderDetailsRepository? repository;

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  Future<ActivityItem?>? _future;

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

  Future<ActivityItem?>? _load() {
    if (!_hasOrderReference) {
      return null;
    }
    return _repository.fetchOrderById(
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
      title: 'Track Order',
      showBackButton: true,
      body: !_hasOrderReference
          ? const _TrackOrderMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No order selected',
              message:
                  'Open "Track order" from an order in your Activity tab '
                  'to see its status here.',
            )
          : FutureBuilder<ActivityItem?>(
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
                return _TrackOrderContent(order: order);
              },
            ),
    );
  }
}

class _TrackOrderContent extends StatelessWidget {
  const _TrackOrderContent({required this.order});

  final ActivityItem order;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return ListView(
      padding: const EdgeInsets.all(TwSpacing.x5),
      children: [
        OutlinedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TwText.fontBoldBase,
                        ),
                        const SizedBox(height: TwSpacing.rhythmTight),
                        Text(
                          'Order #${order.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TwText.textXs.copyWith(
                            color: TwColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TwSpacing.x2),
                  StatusPill(
                    label: order.status,
                    backgroundColor: palette.soft,
                    foregroundColor: palette.accent,
                  ),
                ],
              ),
              const SizedBox(height: TwSpacing.rhythmSection),
              // Only one real status value ever exists for an order today
              // (issue #79) — show it as the single known-reached step
              // rather than fabricating a multi-stage timeline that
              // assumes earlier stages happened.
              _TimelineStepRow(
                step: _TimelineStep(
                  label: order.status,
                  isCompleted: true,
                  hasConnector: true,
                ),
              ),
              const _TimelineStepRow(
                step: _TimelineStep(
                  label: 'Further updates not available yet',
                  isCompleted: false,
                  hasConnector: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TwSpacing.rhythmSection),
        OutlinedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delivery details', style: TwText.fontBoldSm),
              const SizedBox(height: TwSpacing.x2),
              Text(
                "We'll show live courier and delivery updates here as soon "
                "as they're available.",
                style: TwText.textXs.copyWith(color: TwColors.textMuted),
              ),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x2),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
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
                Container(width: 2, height: 40, color: palette.accent),
            ],
          ),
          const SizedBox(width: TwSpacing.x5),
          Expanded(
            child: Text(
              step.label,
              style: TwText.fontBoldSm.copyWith(
                color: step.isCompleted ? TwColors.text : TwColors.textMuted,
              ),
            ),
          ),
        ],
      ),
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
