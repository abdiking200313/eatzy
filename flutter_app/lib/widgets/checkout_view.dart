import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../platform/localization/app_money.dart';
import 'app_cards.dart';
import 'app_misc.dart';
import 'app_scaffold.dart';

/// One line of a [CheckoutView] order summary, e.g. "Bananas ×2" or
/// "Delivery fee". [amount] is in integer cents.
///
/// [isPending] marks a fee/tax line whose [amount] is not actually known yet
/// (e.g. `service_pricing` hasn't loaded): it renders as
/// "Calculated at checkout" instead of a dollar figure, so the client never
/// shows a fabricated/guessed number. [amount] is ignored when [isPending]
/// is `true` and should be `0`; use [CheckoutLine.pending] rather than
/// setting this directly.
class CheckoutLine {
  const CheckoutLine(this.label, this.amount) : isPending = false;

  const CheckoutLine.pending(this.label) : amount = 0, isPending = true;

  final String label;
  final int amount;
  final bool isPending;

  /// The value to actually display for this line: "Calculated at checkout"
  /// when [isPending], otherwise [amount] formatted as money.
  String get displayValue =>
      isPending ? 'Calculated at checkout' : AppMoney.formatCents(amount);
}

/// A fee/total summary row, visually matching [SummaryRow] but with the
/// value side wrapped in a [Flexible] + ellipsis rather than sized to its
/// natural width.
///
/// [SummaryRow] (in `app_misc.dart`) assumes a short, fixed-format money
/// value and does not constrain it, which is safe for every value it was
/// originally used for but overflows for a [CheckoutLine.pending] row's much
/// longer "Calculated at checkout" text on a narrow, large-text-scale
/// screen. Used in place of [SummaryRow] specifically for
/// fee/tax/total rows, which are the only ones that can ever be pending.
class FeeSummaryRow extends StatelessWidget {
  const FeeSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final labelStyle = isBold ? TwText.fontBoldBase : TwText.textSm;
    final valueStyle = isBold
        ? TwText.fontBoldBase.copyWith(color: TwColors.primary)
        : TwText.fontBoldSm;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: TwSpacing.x3),
        Flexible(
          child: Text(
            value,
            style: valueStyle,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The checkout screen shared by food, grocery (incl. Fresh Meat and
/// Electronics) and pharmacy: an optional delivery note, any
/// vertical-specific sections ([extraSections], e.g. grocery's delivery
/// slot), the order summary with a "Pay on delivery" line, and one
/// "Place order" button.
///
/// There is no address and no payment step (owner decisions, 2026-09-25):
/// the recipient name and phone come from the customer's profile
/// server-side, and every order is paid on delivery.
class CheckoutView extends StatelessWidget {
  const CheckoutView({
    super.key,
    required this.title,
    required this.isEmpty,
    required this.emptyMessage,
    required this.browseLabel,
    required this.onBrowse,
    required this.noteController,
    required this.itemLines,
    required this.feeLines,
    required this.total,
    required this.isSubmitting,
    required this.onSubmit,
    this.extraSections = const [],
    this.errorText,
    this.isLoading = false,
  });

  final String title;
  final bool isEmpty;
  final bool isLoading;
  final String emptyMessage;
  final String browseLabel;
  final VoidCallback onBrowse;
  final TextEditingController noteController;

  /// One row per cart line.
  final List<CheckoutLine> itemLines;

  /// Subtotal, tax, delivery fee — whatever this vertical charges.
  final List<CheckoutLine> feeLines;

  /// `null` when any fee/tax line is still [CheckoutLine.isPending] (pricing
  /// hasn't loaded yet): shown as "Calculated at checkout"
  /// instead of a fabricated number. Placing an order is never blocked on
  /// this — the `place_*_order` RPC remains authoritative regardless.
  final int? total;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final List<Widget> extraSections;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      showBackButton: true,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
          ? CheckoutEmptyState(
              message: emptyMessage,
              browseLabel: browseLabel,
              onBrowse: onBrowse,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                TwSpacing.screenX,
                TwSpacing.x2,
                TwSpacing.screenX,
                TwSpacing.x6,
              ),
              children: [
                CheckoutDeliveryNote(controller: noteController),
                for (final section in extraSections) ...[
                  const SizedBox(height: TwSpacing.x6),
                  section,
                ],
                const SizedBox(height: TwSpacing.x6),
                CheckoutSummaryCard(
                  itemLines: itemLines,
                  feeLines: feeLines,
                  total: total,
                ),
                if (errorText case final error?) ...[
                  const SizedBox(height: TwSpacing.x4),
                  Text(
                    error,
                    key: const Key('checkout-error'),
                    style: TwText.textSm.copyWith(color: TwColors.error),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: isEmpty || isLoading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                TwSpacing.x4,
                TwSpacing.x4,
                TwSpacing.x4,
                TwSpacing.x3,
              ),
              child: GradientActionButton(
                key: const Key('checkout-place-order'),
                label: isSubmitting
                    ? 'Placing order...'
                    : total == null
                    ? 'Place order'
                    : 'Place order • ${AppMoney.formatCents(total!)}',
                onPressed: isSubmitting ? null : onSubmit,
                borderRadius: TwRadius.media,
                padding: const EdgeInsets.symmetric(
                  vertical: TwSpacing.x4,
                  horizontal: TwSpacing.x5,
                ),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: TwColors.onPrimary,
                ),
              ),
            ),
    );
  }
}

/// The only delivery input checkout asks for: an optional free-text note.
class CheckoutDeliveryNote extends StatelessWidget {
  const CheckoutDeliveryNote({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Delivery'),
        const SizedBox(height: TwSpacing.x2),
        Text(
          "We'll call the phone number on your profile to arrange delivery.",
          style: TwText.textSm,
        ),
        const SizedBox(height: TwSpacing.x3),
        TextField(
          key: const Key('checkout-delivery-note'),
          controller: controller,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Delivery note / landmark (optional)',
            hintText: 'e.g. Near the mosque, blue gate',
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TwRadius.xl),
            ),
          ),
        ),
      ],
    );
  }
}

class CheckoutSummaryCard extends StatelessWidget {
  const CheckoutSummaryCard({
    super.key,
    required this.itemLines,
    required this.feeLines,
    required this.total,
  });

  final List<CheckoutLine> itemLines;
  final List<CheckoutLine> feeLines;

  /// `null` when a fee/tax line is still [CheckoutLine.isPending] — see
  /// [CheckoutView.total].
  final int? total;

  @override
  Widget build(BuildContext context) {
    // White card only — a plain OutlinedCard already uses the neutral
    // fill/border tokens.
    return OutlinedCard(
      borderRadius: TwRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order summary', style: TwText.fontBoldBase),
          const SizedBox(height: TwSpacing.x4),
          for (final line in itemLines) ...[
            SummaryRow(label: line.label, value: line.displayValue),
            const SizedBox(height: TwSpacing.x2_5),
          ],
          if (itemLines.isNotEmpty)
            const Divider(
              height: 9,
              indent: TwSpacing.x1,
              endIndent: TwSpacing.x1,
            ),
          for (final line in feeLines) ...[
            FeeSummaryRow(label: line.label, value: line.displayValue),
            const SizedBox(height: TwSpacing.x2_5),
          ],
          const Divider(
            height: 9,
            indent: TwSpacing.x1,
            endIndent: TwSpacing.x1,
          ),
          FeeSummaryRow(
            label: 'Total',
            value: total == null
                ? 'Calculated at checkout'
                : AppMoney.formatCents(total!),
            isBold: true,
          ),
          const SizedBox(height: TwSpacing.x3),
          // Both sides `Flexible` so this can never overflow a narrow,
          // large-text screen — it ellipsizes instead.
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 18,
                color: TwColors.textMuted,
              ),
              const SizedBox(width: TwSpacing.x2),
              Flexible(
                child: Text(
                  'Pay on delivery',
                  style: TwText.textSm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CheckoutEmptyState extends StatelessWidget {
  const CheckoutEmptyState({
    super.key,
    required this.message,
    required this.browseLabel,
    required this.onBrowse,
  });

  final String message;
  final String browseLabel;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_shopping_cart_outlined,
              size: 52,
              color: TwColors.textMuted,
            ),
            const SizedBox(height: TwSpacing.x4),
            Text(message, style: TwText.textXl, textAlign: TextAlign.center),
            const SizedBox(height: TwSpacing.x4),
            TextButton(onPressed: onBrowse, child: Text(browseLabel)),
          ],
        ),
      ),
    );
  }
}

/// Confirms a placed order, then resolves once the customer dismisses it.
Future<void> showOrderPlacedDialog(
  BuildContext context, {
  required String orderId,
  String message = 'Your order was sent to the store. Pay on delivery.',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: TwColors.tertiary, size: 44),
      title: const Text('Order placed'),
      content: Text('$message\n\nReference: $orderId'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('View activity'),
        ),
      ],
    ),
  );
}
