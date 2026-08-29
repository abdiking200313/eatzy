import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../config/theme.dart';
import '../features/cart/models/cart_item.dart';
import '../features/cart/presentation/cart_controller.dart';
import '../platform/localization/app_money.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.cartController});

  final CartController? cartController;

  CartController get _controller => cartController ?? CartController.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final controller = _controller;

        return AppScaffold(
          title: 'My Cart',
          actions: controller.isNotEmpty
              ? [
                  TextButton(
                    onPressed: () => _confirmClear(context, controller),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: TwSpacing.x2),
                ]
              : null,
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : controller.isEmpty
              ? const _EmptyCart()
              : _CartContents(
                  controller: controller,
                  onMutation: (mutation) => _runMutation(context, mutation),
                ),
        );
      },
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    CartController controller,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear your cart?'),
        content: const Text('This will remove every item from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear cart'),
          ),
        ],
      ),
    );

    if (shouldClear == true && context.mounted) {
      await _runMutation(context, controller.clear);
    }
  }

  Future<void> _runMutation(
    BuildContext context,
    Future<void> Function() mutation,
  ) async {
    try {
      await mutation();
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The cart changed, but it could not be saved for next time.',
          ),
        ),
      );
    }
  }
}

class _CartContents extends StatelessWidget {
  const _CartContents({required this.controller, required this.onMutation});

  final CartController controller;
  final void Function(Future<void> Function()) onMutation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TwSpacing.x5),
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Items in Cart')),
            Text(
              '${controller.itemCount} '
              '${controller.itemCount == 1 ? 'item' : 'items'}',
              style: TwText.textSm,
            ),
          ],
        ),
        if (controller.restaurantName != null) ...[
          const SizedBox(height: TwSpacing.x1),
          Text(
            controller.restaurantName!,
            style: TwText.textSm.copyWith(color: TwColors.textMuted),
          ),
        ],
        const SizedBox(height: TwSpacing.x5),
        _CartItemsCard(controller: controller, onMutation: onMutation),
        const SizedBox(height: TwSpacing.x8),
        _CartSummary(controller: controller),
        const SizedBox(height: TwSpacing.x8),
        GradientActionButton(
          label: 'Checkout',
          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          onPressed: () => context.push(AppRoutes.foodCheckout),
        ),
        const SizedBox(height: TwSpacing.x8),
      ],
    );
  }
}

/// One card holding every cart line item with internal dividers between
/// rows, per the redesign's "one card per list" rule — never a separate
/// card per line item.
class _CartItemsCard extends StatelessWidget {
  const _CartItemsCard({required this.controller, required this.onMutation});

  final CartController controller;
  final void Function(Future<void> Function()) onMutation;

  @override
  Widget build(BuildContext context) {
    final items = controller.items;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _CartItemRow(
              item: items[index],
              onDecrease: items[index].quantity == 1
                  ? null
                  : () => onMutation(
                      () => controller.decrement(items[index].menuItemId),
                    ),
              onIncrease:
                  items[index].quantity == CartController.maximumQuantity
                  ? null
                  : () => onMutation(
                      () => controller.increment(items[index].menuItemId),
                    ),
              onRemove: () =>
                  onMutation(() => controller.remove(items[index].menuItemId)),
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

  final CartItem item;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CartItemImage(imageUrl: item.imageUrl),
        const SizedBox(width: TwSpacing.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.fontBoldBase,
                    ),
                  ),
                  SizedBox.square(
                    dimension: 32,
                    child: IconButton(
                      key: ValueKey('remove-cart-item-${item.menuItemId}'),
                      tooltip: 'Remove ${item.name}',
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
                _formatCurrency(item.total),
                style: TwText.fontBoldSm.copyWith(color: TwColors.primary),
              ),
              const SizedBox(height: TwSpacing.rhythmDefault),
              _QuantitySelector(
                item: item,
                onDecrease: onDecrease,
                onIncrease: onIncrease,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItemImage extends StatelessWidget {
  const _CartItemImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final fallback = Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.soft,
      ),
      child: Icon(Icons.lunch_dining_rounded, color: palette.accent, size: 32),
    );

    if (imageUrl.trim().isEmpty) {
      return fallback;
    }

    // Decode at roughly the rendered 82x82 box scaled for device pixel
    // density, not at the source image's native resolution. Capped at 3x
    // since a wider cap buys no visible sharpness on a thumbnail this
    // small while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheSize = (82 * cacheScale).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 82,
        height: 82,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
  });

  final CartItem item;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    // A `Wrap` rather than a `Row` so the "$X each" note drops to its own
    // line instead of overflowing on a narrow screen with enlarged text.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TwSpacing.x3,
      runSpacing: TwSpacing.x1,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuantityButton(
              key: ValueKey('decrease-cart-item-${item.menuItemId}'),
              tooltip: 'Decrease ${item.name}',
              icon: Icons.remove_rounded,
              onPressed: onDecrease,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${item.quantity}',
                textAlign: TextAlign.center,
                style: TwText.fontBoldSm,
              ),
            ),
            _QuantityButton(
              key: ValueKey('increase-cart-item-${item.menuItemId}'),
              tooltip: 'Increase ${item.name}',
              icon: Icons.add_rounded,
              onPressed: onIncrease,
            ),
          ],
        ),
        Text(
          '${_formatCurrency(item.unitPrice)} each',
          style: TwText.textXs.copyWith(color: TwColors.textMuted),
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
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.controller});

  final CartController controller;

  @override
  Widget build(BuildContext context) {
    // White card only — OutlinedCard's default fill/border are already the
    // neutral tokens, so no service-tinted override here.
    return OutlinedCard(
      child: Column(
        children: [
          SummaryRow(
            label: 'Subtotal',
            value: _formatCurrency(controller.subtotal),
          ),
          const SizedBox(height: TwSpacing.x4),
          SummaryRow(label: 'Tax', value: _formatCurrency(controller.tax)),
          const SizedBox(height: TwSpacing.x4),
          SummaryRow(
            label: 'Delivery',
            value: _formatCurrency(controller.deliveryFee),
          ),
          const SizedBox(height: TwSpacing.x4),
          const Divider(),
          const SizedBox(height: TwSpacing.x4),
          SummaryRow(
            label: 'Total',
            value: _formatCurrency(controller.total),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: TwColors.textMuted,
            ),
            const SizedBox(height: TwSpacing.x5),
            Text('Your cart is empty', style: TwText.textXl),
            const SizedBox(height: TwSpacing.x2),
            Text(
              'Choose something delicious from a restaurant menu.',
              textAlign: TextAlign.center,
              style: TwText.textSm,
            ),
            const SizedBox(height: TwSpacing.x5),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.food),
              icon: const Icon(Icons.restaurant_menu_rounded),
              label: const Text('Browse restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCurrency(num amount) {
  return AppMoney.format(amount);
}
