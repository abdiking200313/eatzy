import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';

class GroceryCartScreen extends StatelessWidget {
  const GroceryCartScreen({super.key, this.controller});

  final GroceryController? controller;

  GroceryController get _controller => controller ?? GroceryController.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppScaffold(
          title: 'Grocery cart',
          showBackButton: true,
          body: _controller.isEmpty
              ? _EmptyCart(onBrowse: () => context.go(AppRoutes.grocery))
              : _CartBody(controller: _controller),
          bottomNavigationBar: _controller.isEmpty
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.all(TwSpacing.x4),
                  child: GradientActionButton(
                    label: 'Continue • ${AppMoney.format(_controller.total)}',
                    onPressed: () => context.push(AppRoutes.groceryCheckout),
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: TwColors.onPrimary,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 56,
              color: TwColors.textMuted,
            ),
            const SizedBox(height: TwSpacing.x4),
            Text('Your grocery cart is empty', style: TwText.textXl),
            const SizedBox(height: TwSpacing.x5),
            PrimaryButton(
              label: 'Browse groceries',
              fullWidth: false,
              onPressed: onBrowse,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBody extends StatelessWidget {
  const _CartBody({required this.controller});

  final GroceryController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TwSpacing.x5,
        TwSpacing.x2,
        TwSpacing.x5,
        TwSpacing.x8,
      ),
      children: [
        Text(controller.storeName ?? 'Grocery store', style: TwText.textXl),
        const SizedBox(height: TwSpacing.x4),
        _CartLinesCard(controller: controller),
        const SizedBox(height: TwSpacing.x5),
        // White card only — a plain OutlinedCard already uses the neutral
        // fill/border tokens.
        OutlinedCard(
          child: Column(
            children: [
              _TotalRow(label: 'Subtotal', amount: controller.subtotal),
              const SizedBox(height: TwSpacing.x2),
              _TotalRow(label: 'Delivery', amount: controller.deliveryFee),
              const Divider(height: TwSpacing.x6),
              _TotalRow(
                label: 'Total',
                amount: controller.total,
                emphasized: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One card holding every cart line with internal dividers between rows,
/// per the redesign's "one card per list" rule — never a separate card per
/// line item.
class _CartLinesCard extends StatelessWidget {
  const _CartLinesCard({required this.controller});

  final GroceryController controller;

  @override
  Widget build(BuildContext context) {
    final lines = controller.cart;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Column(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            _CartLineRow(line: lines[index], controller: controller),
            if (index != lines.length - 1) ...[
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

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({required this.line, required this.controller});

  final GroceryCartLine line;
  final GroceryController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(line.product.icon, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: TwSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.product.name, style: TwText.fontBoldBase),
              Text(AppMoney.format(line.total), style: TwText.textSm),
              TextButton(
                onPressed: () => controller.remove(line.product.id),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Decrease ${line.product.name}',
          onPressed: () => controller.decrement(line.product.id),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 52,
          child: Text(
            _quantityLabel(line),
            textAlign: TextAlign.center,
            style: TwText.fontBoldSm,
          ),
        ),
        IconButton(
          tooltip: 'Increase ${line.product.name}',
          onPressed: () {
            final changed = controller.increment(line.product.id);
            if (!changed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No more ${line.product.name} is available.'),
                ),
              );
            }
          },
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  String _quantityLabel(GroceryCartLine line) {
    if (line.product.pricingUnit == GroceryPricingUnit.kilogram) {
      return '${line.quantity.toStringAsFixed(1)} kg';
    }
    return line.quantity.toInt().toString();
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized ? TwText.fontBoldBase : TwText.textSm;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(AppMoney.format(amount), style: style),
      ],
    );
  }
}
