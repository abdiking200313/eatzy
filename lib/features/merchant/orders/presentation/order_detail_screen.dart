import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../config/tailwind.dart';
import '../../../../platform/localization/app_money.dart';
import '../models/merchant_order.dart';
import '../models/merchant_order_vertical.dart';
import 'merchant_orders_controller.dart';

/// Order detail view (ported from `merchant_app`, originally issue #134,
/// unified into the main app by issue #232): line items, the
/// customer-facing address/contact info already captured on the order,
/// current status, and the accept/reject/advance actions that call
/// `advance_*_order_status` (issue #131) -- no direct table writes.
///
/// Reads its order live from [controller] (by [orderId]) rather than taking
/// a snapshot, so a status change made from this screen -- or from a
/// pull-to-refresh back on the list -- is reflected immediately without
/// needing to pop and re-push.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.controller,
    required this.orderId,
  });

  final MerchantOrdersController controller;
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  Future<void> _advance(String newStatus) async {
    final order = widget.controller.orderById(widget.orderId);
    if (order == null) return;
    final succeeded = await widget.controller.advanceStatus(order, newStatus);
    if (!mounted) return;
    if (succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order marked as ${merchantOrderStatusLabel(newStatus)}.',
          ),
        ),
      );
    } else {
      final message =
          widget.controller.saveError ??
          'The order status could not be updated. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.controller.orderById(widget.orderId);
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: order == null
          ? const _OrderGoneMessage()
          : _OrderDetailBody(
              order: order,
              isSaving: widget.controller.isSaving,
              onAdvance: (status) => unawaited(_advance(status)),
            ),
    );
  }
}

class _OrderGoneMessage extends StatelessWidget {
  const _OrderGoneMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: TwSpacing.x3),
            const Text(
              'This order is no longer available.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({
    required this.order,
    required this.isSaving,
    required this.onAdvance,
  });

  final MerchantOrder order;
  final bool isSaving;
  final ValueChanged<String> onAdvance;

  @override
  Widget build(BuildContext context) {
    final vertical = order.vertical;
    final nextStatus = nextForwardOrderStatus(vertical, order.status);
    final isConfirmed = order.status == vertical.orderStatusFlow.first;
    final canCancel = canCancelOrder(vertical, order.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TwSpacing.screenX,
        TwSpacing.x4,
        TwSpacing.screenX,
        TwSpacing.x6,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${shortOrderId(order.id)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDateTime(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _StatusPill(status: order.status),
          ],
        ),
        const SizedBox(height: TwSpacing.x5),
        _SectionCard(
          title: 'Items',
          child: Column(
            children: [
              for (final item in order.items) _LineItemRow(item: item),
              const Divider(height: 9, indent: 4, endIndent: 4),
              _TotalsRow(label: 'Subtotal', cents: order.subtotalCents),
              _TotalsRow(label: 'Delivery fee', cents: order.deliveryFeeCents),
              if (order.taxCents case final taxCents?)
                _TotalsRow(label: 'Tax', cents: taxCents),
              _TotalsRow(
                label: 'Total',
                cents: order.totalCents,
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: TwSpacing.x3),
        _SectionCard(
          title: 'Delivery details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.recipientName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(order.phone),
              const SizedBox(height: TwSpacing.x2),
              Text(
                order.deliveryLine.isEmpty
                    ? 'No delivery note. Call the customer for directions.'
                    : order.deliveryLine,
              ),
              if (order.deliverySlotLabel case final slot?
                  when slot.trim().isNotEmpty) ...[
                const SizedBox(height: TwSpacing.x2),
                Text('Delivery window: $slot'),
              ],
              if (substitutionPreferenceLabel(order.substitutionPreference)
                  case final substitution?) ...[
                const SizedBox(height: TwSpacing.x2),
                Text(substitution),
              ],
              if (order.deliveryInstructions case final instructions?
                  when instructions.trim().isNotEmpty) ...[
                const SizedBox(height: TwSpacing.x2),
                Text('Instructions: $instructions'),
              ],
            ],
          ),
        ),
        if (order.paymentMethod != null || order.paymentStatus != null) ...[
          const SizedBox(height: TwSpacing.x3),
          _SectionCard(
            title: 'Payment',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.paymentMethod != null)
                  Text(_paymentMethodLabel(order.paymentMethod!)),
                if (order.paymentStatus != null)
                  Text(_paymentStatusLabel(order.paymentStatus!)),
              ],
            ),
          ),
        ],
        const SizedBox(height: TwSpacing.x5),
        if (nextStatus == null && !canCancel)
          const Text(
            'This order is complete. No further action is available.',
            textAlign: TextAlign.center,
          )
        else
          Row(
            children: [
              if (canCancel)
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : () => onAdvance('cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: Text(isConfirmed ? 'Reject order' : 'Cancel order'),
                  ),
                ),
              if (canCancel && nextStatus != null)
                const SizedBox(width: TwSpacing.x3),
              if (nextStatus != null)
                Expanded(
                  child: FilledButton(
                    onPressed: isSaving ? null : () => onAdvance(nextStatus),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isConfirmed
                                ? 'Accept order'
                                : 'Mark as ${merchantOrderStatusLabel(nextStatus)}',
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TwSpacing.headerToContent),
            child,
          ],
        ),
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.item});

  final MerchantOrderLineItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TwSpacing.x1),
      child: Row(
        children: [
          Text(
            '${item.quantity}x',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: TwSpacing.x2),
          Expanded(child: Text(item.name)),
          Text(AppMoney.formatCents(item.lineTotalCents)),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
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
        ? Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(AppMoney.formatCents(cents), style: style),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x2_5,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(TwRadius.full),
      ),
      child: Text(
        merchantOrderStatusLabel(status),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

/// Mirrors the root app's `ActivityItem.paymentMethodLabel` (issue #30):
/// only `cash_on_delivery` is a real value today, but any other raw value
/// still renders as something readable.
String _paymentMethodLabel(String raw) => switch (raw) {
  'cash_on_delivery' => 'Cash on delivery',
  final other => other,
};

/// Mirrors the root app's `ActivityItem.paymentStatusLabel` (issue #30).
String _paymentStatusLabel(String raw) => switch (raw) {
  'pending_collection' => 'Pending collection',
  'collected' => 'Collected',
  'refunded' => 'Refunded',
  final other => other,
};
