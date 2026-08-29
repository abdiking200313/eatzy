import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/add_to_cart_button.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
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

  // Mirrors only the catalog-load-relevant slice of the controller's state.
  // Cart mutations (add/increment/decrement/remove) also call
  // `notifyListeners()` on the same controller, but don't change any of
  // these fields — so `_handleControllerChanged` skips the `setState` and
  // this screen's (potentially large) product list is left unbuilt. Only
  // the cart badge in `_CartAction` listens for those changes directly.
  late bool _isLoading;
  late bool _isLoadingMore;
  late bool _hasMore;
  late int _productCount;
  late String? _loadError;

  @override
  void initState() {
    super.initState();
    // Kick off the load first: its synchronous prefix (setting `isLoading`
    // and calling `notifyListeners()`) runs immediately, before the first
    // `await`. Snapshotting state after that call — rather than listening
    // first — means our own `setState` only ever runs in response to a
    // later, async notification, never re-entrantly during this
    // `initState()`/first-build pass.
    unawaited(_controller.loadProducts());
    _syncLoadState();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _syncLoadState() {
    _isLoading = _controller.isLoading;
    _isLoadingMore = _controller.isLoadingMore;
    _hasMore = _controller.hasMore;
    _productCount = _controller.products.length;
    _loadError = _controller.loadError;
  }

  void _handleControllerChanged() {
    final isLoading = _controller.isLoading;
    final isLoadingMore = _controller.isLoadingMore;
    final hasMore = _controller.hasMore;
    final productCount = _controller.products.length;
    final loadError = _controller.loadError;
    if (isLoading == _isLoading &&
        isLoadingMore == _isLoadingMore &&
        hasMore == _hasMore &&
        productCount == _productCount &&
        loadError == _loadError) {
      return;
    }
    setState(() {
      _isLoading = isLoading;
      _isLoadingMore = isLoadingMore;
      _hasMore = hasMore;
      _productCount = productCount;
      _loadError = loadError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pharmacy',
      showBackButton: true,
      actions: [
        _CartAction(
          controller: _controller,
          onPressed: () => context.push(AppRoutes.pharmacyCart),
        ),
        const SizedBox(width: TwSpacing.x2),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _productCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _productCount == 0) {
      return _CatalogError(
        message: _loadError!,
        onRetry: _controller.loadProducts,
      );
    }

    // 2 fixed header rows (notice + heading block) + one row per product +
    // an optional trailing "load more" row.
    final itemCount = 2 + _productCount + (_hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => _controller.loadProducts(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(TwSpacing.x5),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: TwSpacing.rhythmDefault),
              child: _OtcNotice(),
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: TwSpacing.rhythmDefault),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health essentials', style: TwText.textXl),
                  const SizedBox(height: TwSpacing.x1),
                  Text(
                    'Seeded products for the interactive Zivo preview.',
                    style: TwText.textSm,
                  ),
                ],
              ),
            );
          }

          final productIndex = index - 2;
          if (productIndex >= _productCount) {
            // Trailing load-more row: triggers the next page once it comes
            // into view instead of eagerly fetching everything up front.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _controller.loadMore();
              }
            });
            return Padding(
              padding: const EdgeInsets.only(top: TwSpacing.x4),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : const SizedBox(height: 32),
              ),
            );
          }

          final product = _controller.products[productIndex];
          return Padding(
            padding: EdgeInsets.only(
              bottom: productIndex == _productCount - 1 && !_hasMore
                  ? TwSpacing.x8
                  : TwSpacing.x3,
            ),
            child: _ProductCard(
              product: product,
              onAdd: () => _addProduct(product),
            ),
          );
        },
      ),
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
    // White card only — the service accent is confined to the icon chip.
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceIconChip(icon: Icons.health_and_safety_outlined),
          const SizedBox(width: TwSpacing.rhythmDefault),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Over-the-counter (OTC) only', style: TwText.fontBoldSm),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(
                  'This preview does not accept prescriptions or include '
                  'regulated medicines. Ask a healthcare professional if you '
                  'are unsure which product is right for you.',
                  style: TwText.textXs,
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
    final stockLabel = !product.isAvailable
        ? 'Out of stock'
        : product.isLowStock
        ? 'Only ${product.stockQuantity} left'
        : 'In stock';

    // White card only — the service accent is confined to the 48px icon
    // chip, never the card fill or border.
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceIconChip(icon: Icons.medication_outlined),
          const SizedBox(width: TwSpacing.rhythmDefault),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.category, style: TwText.link),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(product.name, style: TwText.fontBoldBase),
                const SizedBox(height: TwSpacing.rhythmTight),
                Text(product.description, style: TwText.textSm),
                const SizedBox(height: TwSpacing.rhythmDefault),
                Wrap(
                  spacing: TwSpacing.x3,
                  runSpacing: TwSpacing.x2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      AppMoney.format(product.unitPrice),
                      style: TwText.fontBoldBase.copyWith(
                        color: TwColors.primary,
                      ),
                    ),
                    StatusPill(
                      label: stockLabel,
                      backgroundColor: product.isAvailable
                          ? TwColors.tertiary.withOpacityValue(0.14)
                          : TwColors.errorSoft,
                      foregroundColor: product.isAvailable
                          ? const Color(0xFF0F7A54)
                          : TwColors.error,
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

/// Isolated so a cart mutation (add/increment/decrement/remove) only
/// rebuilds this small badge, not the (potentially long) product list
/// above it.
class _CartAction extends StatelessWidget {
  const _CartAction({required this.controller, required this.onPressed});

  final PharmacyController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final itemCount = controller.itemCount;
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
      },
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
