import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/add_to_cart_button.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key, this.controller});

  final GroceryController? controller;

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  GroceryController get _controller =>
      widget.controller ?? GroceryController.instance;

  @override
  void initState() {
    super.initState();
    if (!_controller.hasLoaded && !_controller.isLoading) {
      unawaited(_controller.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppScaffold(
          title: 'Groceries',
          showBackButton: true,
          actions: [
            IconButton(
              tooltip: 'Grocery cart (${_controller.itemCount})',
              onPressed: () => context.push('/grocery/cart'),
              icon: Badge(
                isLabelVisible: _controller.itemCount > 0,
                label: Text('${_controller.itemCount}'),
                child: const Icon(Icons.shopping_basket_outlined),
              ),
            ),
          ],
          body: _body(),
        );
      },
    );
  }

  Widget _body() {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.loadError case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: TwSpacing.x4),
              PrimaryButton(
                label: 'Try again',
                fullWidth: false,
                onPressed: _controller.load,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TwSpacing.x4,
        TwSpacing.x2,
        TwSpacing.x4,
        TwSpacing.x8,
      ),
      children: [
        Text('Essentials from Somali stores', style: TwText.textXl()),
        const SizedBox(height: TwSpacing.x2),
        Text(
          'Products marked per kg can be added in 0.5 kg steps.',
          style: TwText.textSm(),
        ),
        const SizedBox(height: TwSpacing.x6),
        for (final store in _controller.stores) ...[
          _StoreHeader(store: store),
          const SizedBox(height: TwSpacing.x3),
          for (final product in store.products) ...[
            _ProductCard(product: product, onAdd: () => _add(product)),
            const SizedBox(height: TwSpacing.x3),
          ],
          const SizedBox(height: TwSpacing.x5),
        ],
      ],
    );
  }

  Future<void> _add(GroceryProduct product) async {
    var result = _controller.addProduct(product);
    if (result == GroceryAddResult.storeConflict) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new store cart?'),
          content: const Text(
            'The grocery MVP keeps one store per checkout. Your current '
            'grocery cart will be replaced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current cart'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace cart'),
            ),
          ],
        ),
      );
      if (replace == true) {
        result = _controller.addProduct(product, replaceStoreCart: true);
      }
    }

    if (!mounted) {
      return;
    }
    final message = switch (result) {
      GroceryAddResult.added => '${product.name} added to your grocery cart.',
      GroceryAddResult.quantityIncreased =>
        '${product.name} quantity increased.',
      GroceryAddResult.unavailable => '${product.name} is out of stock.',
      GroceryAddResult.stockLimitReached =>
        'No more ${product.name} is available.',
      GroceryAddResult.storeConflict => 'Your current grocery cart was kept.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final GroceryStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(store.name, style: TwText.textXl())),
        Text(store.area, style: TwText.textXs()),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final GroceryProduct product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final stockLabel = switch (product.stockState) {
      GroceryStockState.inStock => 'In stock',
      GroceryStockState.lowStock => 'Low stock',
      GroceryStockState.outOfStock => 'Out of stock',
    };
    final stockColor = switch (product.stockState) {
      GroceryStockState.inStock => palette.accent,
      GroceryStockState.lowStock => Colors.orange.shade800,
      GroceryStockState.outOfStock => TwColors.error,
    };

    return OutlinedCard(
      backgroundColor: product.isAvailable ? palette.card : TwColors.stone100,
      borderColor: product.isAvailable ? palette.border : TwColors.stone300,
      child: Row(
        children: [
          Text(product.icon, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: TwText.fontBoldBase()),
                Text(product.description, style: TwText.textSm()),
                const SizedBox(height: TwSpacing.x1),
                Text(
                  '${AppMoney.format(product.unitPrice)} ${product.unitLabel}',
                  style: TwText.fontBoldSm(),
                ),
                Text(
                  stockLabel,
                  style: TwText.textXs().copyWith(color: stockColor),
                ),
              ],
            ),
          ),
          AddToCartButton(
            key: ValueKey('add-grocery-${product.id}'),
            tooltip: product.isAvailable ? 'Add ${product.name}' : stockLabel,
            onPressed: product.isAvailable ? onAdd : null,
          ),
        ],
      ),
    );
  }
}
