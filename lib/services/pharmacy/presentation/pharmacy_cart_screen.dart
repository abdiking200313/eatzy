import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/pharmacy_cart_item.dart';
import 'pharmacy_controller.dart';

class PharmacyCartScreen extends StatelessWidget {
  const PharmacyCartScreen({super.key, this.controller});

  final PharmacyController? controller;

  @override
  Widget build(BuildContext context) {
    final pharmacyController = controller ?? PharmacyController.instance;

    return AnimatedBuilder(
      animation: pharmacyController,
      builder: (context, _) {
        return AppScaffold(
          title: 'Pharmacy cart',
          showBackButton: true,
          actions: pharmacyController.isCartNotEmpty
              ? [
                  TextButton(
                    onPressed: pharmacyController.clearCart,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: TwSpacing.x2),
                ]
              : null,
          body: pharmacyController.isCartEmpty
              ? const _EmptyPharmacyCart()
              : _CartContents(controller: pharmacyController),
        );
      },
    );
  }
}

class _CartContents extends StatelessWidget {
  const _CartContents({required this.controller});

  final PharmacyController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TwSpacing.x5),
      children: [
        const _OtcCartReminder(),
        const SizedBox(height: TwSpacing.x5),
        _CartItemsCard(controller: controller),
        const SizedBox(height: TwSpacing.x6),
        _PharmacySummary(controller: controller),
        const SizedBox(height: TwSpacing.x6),
        GradientActionButton(
          label: 'Continue to checkout',
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.push('/pharmacy/checkout'),
        ),
        const SizedBox(height: TwSpacing.x8),
      ],
    );
  }
}

class _OtcCartReminder extends StatelessWidget {
  const _OtcCartReminder();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your pharmacy cart is separate from food and grocery. '
      'All listed products are OTC.',
      style: TwText.textSm(),
    );
  }
}

/// One card holding every pharmacy cart line item with internal dividers
/// between rows, per the redesign's "one card per list" rule — never a
/// separate card per line item.
class _CartItemsCard extends StatelessWidget {
  const _CartItemsCard({required this.controller});

  final PharmacyController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.cartItems;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _CartItemRow(
              item: items[index],
              onDecrease: () => controller.decrement(items[index].product.id),
              onIncrease:
                  items[index].quantity < items[index].product.stockQuantity
                  ? () => controller.increment(items[index].product.id)
                  : null,
              onRemove: () => controller.removeProduct(items[index].product.id),
            ),
            if (index != items.length - 1) ...[
              const SizedBox(height: TwSpacing.rhythmDefault),
              const Divider(),
              const SizedBox(height: TwSpacing.rhythmDefault),
            ],
          ],
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final PharmacyCartItem item;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ServiceIconChip(icon: Icons.medication_outlined),
        const SizedBox(width: TwSpacing.rhythmDefault),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.fontBoldBase(),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 32,
                    child: IconButton(
                      key: ValueKey('remove-pharmacy-${item.product.id}'),
                      tooltip: 'Remove ${item.product.name}',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: TwColors.textMuted,
                      ),
                      onPressed: onRemove,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TwSpacing.rhythmTight),
              Text(
                AppMoney.format(item.total),
                style: TwText.fontBoldSm().copyWith(color: TwColors.primary),
              ),
              const SizedBox(height: TwSpacing.rhythmDefault),
              // A `Wrap` rather than a `Row` so the "$X each" note drops to
              // its own line instead of overflowing on a narrow screen with
              // enlarged text.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: TwSpacing.x3,
                runSpacing: TwSpacing.x1,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QuantityButton(
                        key: ValueKey('decrease-pharmacy-${item.product.id}'),
                        tooltip: 'Decrease ${item.product.name}',
                        icon: Icons.remove,
                        onPressed: onDecrease,
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: TwText.fontBoldSm(),
                        ),
                      ),
                      _QuantityButton(
                        key: ValueKey('increase-pharmacy-${item.product.id}'),
                        tooltip: 'Increase ${item.product.name}',
                        icon: Icons.add,
                        onPressed: onIncrease,
                      ),
                    ],
                  ),
                  Text(
                    '${AppMoney.format(item.product.unitPrice)} each',
                    style: TwText.textXs().copyWith(color: TwColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton.outlined(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
      ),
    );
  }
}

class _PharmacySummary extends StatelessWidget {
  const _PharmacySummary({required this.controller});

  final PharmacyController controller;

  @override
  Widget build(BuildContext context) {
    // White card only — a plain OutlinedCard already uses the neutral
    // fill/border tokens.
    return OutlinedCard(
      child: Column(
        children: [
          _SummaryRow(
            label: 'Subtotal',
            value: AppMoney.format(controller.subtotal),
          ),
          const SizedBox(height: TwSpacing.x3),
          _SummaryRow(
            label: 'Delivery in Somalia',
            value: AppMoney.format(PharmacyController.deliveryFee),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TwSpacing.x3),
            child: Divider(),
          ),
          _SummaryRow(
            label: 'Total',
            value: AppMoney.format(controller.total),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final style = isBold ? TwText.fontBoldBase() : TwText.textSm();
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _EmptyPharmacyCart extends StatelessWidget {
  const _EmptyPharmacyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              color: TwColors.textMuted,
              size: 52,
            ),
            const SizedBox(height: TwSpacing.x4),
            Text('Your pharmacy cart is empty', style: TwText.textXl()),
            const SizedBox(height: TwSpacing.x2),
            Text(
              'Browse OTC health essentials to get started.',
              textAlign: TextAlign.center,
              style: TwText.textSm(),
            ),
            const SizedBox(height: TwSpacing.x4),
            TextButton(
              onPressed: () => context.go('/pharmacy'),
              child: const Text('Browse pharmacy'),
            ),
          ],
        ),
      ),
    );
  }
}
