import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
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
        for (var index = 0; index < controller.cartItems.length; index++) ...[
          _CartItemCard(
            item: controller.cartItems[index],
            onDecrease: () =>
                controller.decrement(controller.cartItems[index].product.id),
            onIncrease:
                controller.cartItems[index].quantity <
                    controller.cartItems[index].product.stockQuantity
                ? () => controller.increment(
                    controller.cartItems[index].product.id,
                  )
                : null,
            onRemove: () => controller.removeProduct(
              controller.cartItems[index].product.id,
            ),
          ),
          if (index != controller.cartItems.length - 1)
            const SizedBox(height: TwSpacing.x3),
        ],
        const SizedBox(height: TwSpacing.x6),
        _PharmacySummary(controller: controller),
        const SizedBox(height: TwSpacing.x6),
        GradientActionButton(
          label: 'Continue to checkout',
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.push(AppRoutes.pharmacyCheckout),
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

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
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
    final palette = context.serviceColors;
    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: palette.soft,
            foregroundColor: palette.accent,
            child: const Icon(Icons.medication_outlined),
          ),
          const SizedBox(width: TwSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, style: TwText.fontBoldBase()),
                Text(
                  '${AppMoney.format(item.product.unitPrice)} each',
                  style: TwText.textSm(),
                ),
                const SizedBox(height: TwSpacing.x2),
                Row(
                  children: [
                    IconButton.outlined(
                      key: ValueKey('decrease-pharmacy-${item.product.id}'),
                      tooltip: 'Decrease ${item.product.name}',
                      onPressed: onDecrease,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TwSpacing.x2,
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: TwText.fontBoldSm(),
                      ),
                    ),
                    IconButton.outlined(
                      key: ValueKey('increase-pharmacy-${item.product.id}'),
                      tooltip: 'Increase ${item.product.name}',
                      onPressed: onIncrease,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey('remove-pharmacy-${item.product.id}'),
                tooltip: 'Remove ${item.product.name}',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
              Text(
                AppMoney.format(item.total),
                style: TwText.fontBoldSm().copyWith(color: palette.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PharmacySummary extends StatelessWidget {
  const _PharmacySummary({required this.controller});

  final PharmacyController controller;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: context.serviceColors.card,
      borderColor: context.serviceColors.border,
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
            Icon(
              Icons.shopping_bag_outlined,
              color: context.serviceColors.accent,
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
              onPressed: () => context.go(AppRoutes.pharmacy),
              child: const Text('Browse pharmacy'),
            ),
          ],
        ),
      ),
    );
  }
}
