import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/add_to_cart_button.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/pharmacy_product.dart';
import 'pharmacy_controller.dart';

class PharmacyCatalogScreen extends StatefulWidget {
  const PharmacyCatalogScreen({super.key, this.controller});

  final PharmacyController? controller;

  @override
  State<PharmacyCatalogScreen> createState() => _PharmacyCatalogScreenState();
}

class _PharmacyCatalogScreenState extends State<PharmacyCatalogScreen> {
  PharmacyController get _controller =>
      widget.controller ?? PharmacyController.instance;

  @override
  void initState() {
    super.initState();
    _controller.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppScaffold(
          title: 'Pharmacy',
          showBackButton: true,
          actions: [
            _CartAction(
              itemCount: _controller.itemCount,
              onPressed: () => context.push('/pharmacy/cart'),
            ),
            const SizedBox(width: TwSpacing.x2),
          ],
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.loadError != null && _controller.products.isEmpty) {
      return _CatalogError(
        message: _controller.loadError!,
        onRetry: _controller.loadProducts,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(TwSpacing.x5),
      children: [
        const _OtcNotice(),
        const SizedBox(height: TwSpacing.rhythmDefault),
        Text('Health essentials', style: TwText.textXl()),
        const SizedBox(height: TwSpacing.x1),
        Text(
          'Seeded products for the interactive Zivo preview.',
          style: TwText.textSm(),
        ),
        const SizedBox(height: TwSpacing.rhythmDefault),
        for (var index = 0; index < _controller.products.length; index++) ...[
          _ProductCard(
            product: _controller.products[index],
            onAdd: () => _addProduct(_controller.products[index]),
          ),
          if (index != _controller.products.length - 1)
            const SizedBox(height: TwSpacing.x3),
        ],
        const SizedBox(height: TwSpacing.x8),
      ],
    );
  }

  void _addProduct(PharmacyProduct product) {
    final result = _controller.addProduct(product);
    final message = switch (result) {
      PharmacyCartAddResult.added => '${product.name} added to pharmacy cart.',
      PharmacyCartAddResult.quantityIncreased =>
        '${product.name} quantity increased.',
      PharmacyCartAddResult.notOverTheCounter =>
        '${product.name} is not eligible for OTC ordering.',
      PharmacyCartAddResult.unavailable =>
        '${product.name} is currently out of stock.',
      PharmacyCartAddResult.maximumStockReached =>
        'You already have all available ${product.name} in your cart.',
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OtcNotice extends StatelessWidget {
  const _OtcNotice();

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: palette.accent),
          const SizedBox(width: TwSpacing.rhythmTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Over-the-counter (OTC) only', style: TwText.fontBoldSm()),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(
                  'This preview does not accept prescriptions or include '
                  'regulated medicines. Ask a healthcare professional if you '
                  'are unsure which product is right for you.',
                  style: TwText.textXs(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final PharmacyProduct product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final stockLabel = !product.isAvailable
        ? 'Out of stock'
        : product.isLowStock
        ? 'Only ${product.stockQuantity} left'
        : 'In stock';

    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(TwRadius.xl),
            ),
            child: Icon(
              Icons.medication_outlined,
              color: palette.accent,
              size: 32,
            ),
          ),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.category,
                  style: TwText.link().copyWith(color: palette.accent),
                ),
                const SizedBox(height: TwSpacing.x1),
                Text(product.name, style: TwText.fontBoldBase()),
                const SizedBox(height: TwSpacing.x1),
                Text(product.description, style: TwText.textSm()),
                const SizedBox(height: TwSpacing.x3),
                Wrap(
                  spacing: TwSpacing.x3,
                  runSpacing: TwSpacing.x2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      AppMoney.format(product.unitPrice),
                      style: TwText.fontBoldBase().copyWith(
                        color: palette.accent,
                      ),
                    ),
                    Text(
                      stockLabel,
                      style: TwText.textXs().copyWith(
                        color: product.isAvailable
                            ? TwColors.textMuted
                            : TwColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: TwSpacing.x2),
          AddToCartButton(
            key: ValueKey('add-pharmacy-${product.id}'),
            tooltip: product.isAvailable ? 'Add ${product.name}' : stockLabel,
            onPressed: product.isAvailable ? onAdd : null,
          ),
        ],
      ),
    );
  }
}

class _CartAction extends StatelessWidget {
  const _CartAction({required this.itemCount, required this.onPressed});

  final int itemCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('pharmacy-cart-action'),
      tooltip: 'Pharmacy cart',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: itemCount > 0,
        label: Text('$itemCount'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: TwColors.error, size: 48),
            const SizedBox(height: TwSpacing.x3),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: TwSpacing.x4),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
