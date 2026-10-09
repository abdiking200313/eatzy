import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/product_details_view.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';

/// Full-screen details for one grocery product, reached either by tapping
/// its row in `GroceryStoreScreen` or directly via
/// `AppRoutes.groceryProductDetails` (deep link / browser URL). A go_router
/// destination, like `RestaurantScreen`/`MenuItemDetailsScreen`: it only
/// takes [storeId]/[productId] and loads the product itself
/// from the same [GroceryController] catalog `GroceryStoreScreen` reads
/// from, rather than taking the whole [GroceryProduct] object.
class GroceryProductDetailsScreen extends StatefulWidget {
  const GroceryProductDetailsScreen({
    super.key,
    required this.storeId,
    required this.productId,
    this.storeType = GroceryStoreType.grocery,
    this.controller,
  });

  final String storeId;
  final String productId;

  /// Picks the palette (Grocery / Fresh Meat / Electronics) and which
  /// [GroceryController] (see [AppServices.groceryController]) this screen
  /// reads from.
  final GroceryStoreType storeType;

  /// Overridable for tests; defaults to
  /// `AppScope.of(context).groceryController(storeType)`.
  final GroceryController? controller;

  @override
  State<GroceryProductDetailsScreen> createState() =>
      _GroceryProductDetailsScreenState();
}

class _GroceryProductDetailsScreenState
    extends State<GroceryProductDetailsScreen> {
  /// Resolved once in [didChangeDependencies] -- see
  /// `GroceryStoreScreen._resolvedController` for why this can't happen in
  /// `initState`.
  GroceryController? _resolvedController;
  GroceryController get _controller =>
      widget.controller ?? _resolvedController!;

  bool _didInitializeController = false;
  late bool _isLoading;
  late bool _hasLoaded;
  late String? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeController) {
      return;
    }
    _didInitializeController = true;
    _resolvedController =
        widget.controller ??
        AppScope.of(context).groceryController(widget.storeType);

    // Same store-scoped load `GroceryStoreScreen` uses, so a cold deep link
    // straight to this screen (before the store list/catalog have loaded
    // anything) still resolves the product.
    if ((!_controller.hasLoadedStore(widget.storeId) || _controller.isStale) &&
        !_controller.isLoading) {
      unawaited(_controller.loadStore(widget.storeId));
    }
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
    _hasLoaded = _controller.hasLoadedStore(widget.storeId);
    _loadError = _controller.loadError;
  }

  void _handleControllerChanged() {
    final isLoading = _controller.isLoading;
    final hasLoaded = _controller.hasLoadedStore(widget.storeId);
    final loadError = _controller.loadError;
    if (isLoading == _isLoading &&
        hasLoaded == _hasLoaded &&
        loadError == _loadError) {
      return;
    }
    setState(() {
      _isLoading = isLoading;
      _hasLoaded = hasLoaded;
      _loadError = loadError;
    });
  }

  GroceryProduct? _findProduct() {
    for (final store in _controller.stores) {
      if (store.id != widget.storeId) continue;
      for (final product in store.products) {
        if (product.id == widget.productId) return product;
      }
    }
    return null;
  }

  /// Mirrors `GroceryStoreScreen._add` -- the cart-conflict dialog and
  /// snackbar are identical since this screen is reached the same way (a
  /// tap from that store's catalog, or a deep link to the same product).
  Future<void> _add(GroceryProduct product, {int steps = 1}) async {
    var result = _controller.addProduct(product, steps: steps);
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
        result = _controller.addProduct(
          product,
          replaceStoreCart: true,
          steps: steps,
        );
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
    showCartSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final product = _findProduct();
    if (product == null) {
      final body = _isLoading && !_hasLoaded
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ErrorView(
              message: _loadError!,
              onRetry: () => _controller.loadStore(widget.storeId),
            )
          : const _ProductNotFoundView();
      return AppScaffold(title: 'Product', showBackButton: true, body: body);
    }

    final inCart = _controller.cart
        .where((line) => line.product.id == product.id)
        .fold<double>(0, (total, line) => total + line.quantity);
    final step = product.quantityStep;
    final remaining = product.isAvailable
        ? product.availableQuantity - inCart
        : 0.0;
    // Tolerance guards against float error in e.g. 2.5 / 0.5.
    final maxSteps = (remaining / step + 1e-9).floor();
    final isByWeight = product.pricingUnit == GroceryPricingUnit.kilogram;

    return ZivoServiceTheme(
      serviceId: ServiceId.grocery,
      palette: widget.storeType.palette,
      child: ProductDetailsView(
        imageUrl: product.imageUrl,
        fallback: Text(product.icon, style: const TextStyle(fontSize: 96)),
        name: product.name,
        priceLabel:
            '${AppMoney.formatCents(product.unitPrice)} ${product.unitLabel}',
        stockLabel: switch (product.stockState) {
          GroceryStockState.inStock => 'In stock',
          GroceryStockState.lowStock => 'Low stock',
          GroceryStockState.outOfStock => 'Out of stock',
        },
        isInStock: product.isAvailable,
        description: product.description,
        facts: [if (isByWeight) 'Sold by weight, in 0.5 kg steps.'],
        maxSteps: maxSteps,
        unavailableLabel: product.isAvailable
            ? 'All stock in cart'
            : 'Out of stock',
        quantityLabel: (steps) {
          if (!isByWeight) return '$steps';
          final kg = steps * step;
          return '${kg == kg.roundToDouble() ? kg.toInt() : kg} kg';
        },
        onAddToCart: (steps) => unawaited(_add(product, steps: steps)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: TwSpacing.x4),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Shown for a cold deep link to a [GroceryProductDetailsScreen.productId]
/// that no longer resolves in [GroceryProductDetailsScreen.storeId]'s loaded
/// catalog (e.g. a stale/bad id, or the product was removed) -- doesn't
/// crash.
class _ProductNotFoundView extends StatelessWidget {
  const _ProductNotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(TwSpacing.x6),
        child: Text(
          'This product is no longer available.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
