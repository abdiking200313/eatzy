import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/product_details_view.dart';
import '../models/pharmacy_product.dart';
import 'pharmacy_controller.dart';

/// Full-screen details for one pharmacy product, reached either by tapping
/// its row in `PharmacyCatalogScreen` or directly via
/// `AppRoutes.pharmacyProductDetails` (deep link / browser URL). A
/// go_router destination, like `RestaurantScreen`/`MenuItemDetailsScreen`
/// (issue #288): it only takes [storeId]/[productId] and loads the product
/// itself from the same [PharmacyController] catalog `PharmacyCatalogScreen`
/// reads from, rather than taking the whole [PharmacyProduct] object.
class PharmacyProductDetailsScreen extends StatefulWidget {
  const PharmacyProductDetailsScreen({
    super.key,
    required this.storeId,
    required this.productId,
    this.controller,
  });

  final String storeId;
  final String productId;

  /// Overridable for tests; defaults to
  /// `AppScope.of(context).pharmacyController`.
  final PharmacyController? controller;

  @override
  State<PharmacyProductDetailsScreen> createState() =>
      _PharmacyProductDetailsScreenState();
}

class _PharmacyProductDetailsScreenState
    extends State<PharmacyProductDetailsScreen> {
  /// Resolved once in [didChangeDependencies] -- see
  /// `PharmacyCatalogScreen._resolvedController` for why this can't happen
  /// in `initState`.
  PharmacyController? _resolvedController;
  PharmacyController get _controller =>
      widget.controller ?? _resolvedController!;

  bool _didInitializeController = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeController) {
      return;
    }
    _didInitializeController = true;
    _resolvedController =
        widget.controller ?? AppScope.of(context).pharmacyController;

    // Same per-store load `PharmacyCatalogScreen` uses, so a cold deep link
    // straight to this screen resolves the product too.
    //
    // TODO(supabase/logic-agent): this only loads the catalog's first page
    // (`pharmacyProductsPageSize`), same as `PharmacyCatalogScreen` -- a deep
    // link to a product past that first page won't resolve. A dedicated
    // single-product fetch (e.g.
    // `PharmacyRepository.fetchProduct({required String storeId, required
    // String productId})`) would close that gap; not added here since it's
    // a data-layer change.
    unawaited(_controller.loadProducts(storeId: widget.storeId));
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() => setState(() {});

  PharmacyProduct? _findProduct() {
    for (final product in _controller.products) {
      if (product.id == widget.productId) return product;
    }
    return null;
  }

  /// Mirrors `PharmacyCatalogScreen._addProduct` -- the cart-conflict
  /// dialog and snackbar are identical since this screen is reached the
  /// same way (a tap from that pharmacy's catalog, or a deep link to the
  /// same product).
  Future<void> _addProduct(PharmacyProduct product, {int quantity = 1}) async {
    var result = _controller.addProduct(product, quantity: quantity);

    if (result == PharmacyCartAddResult.storeConflict) {
      final replaceCart = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start a new pharmacy cart?'),
          content: const Text(
            'Your pharmacy cart contains items from another pharmacy. '
            'Starting a cart here will remove them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep cart'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start new cart'),
            ),
          ],
        ),
      );

      if (replaceCart != true) {
        return;
      }
      if (!mounted) {
        return;
      }
      result = _controller.addProduct(
        product,
        replaceStoreCart: true,
        quantity: quantity,
      );
    }

    if (!mounted) {
      return;
    }
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
      PharmacyCartAddResult.storeConflict =>
        'Your pharmacy cart was kept unchanged.',
    };

    showCartSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final product = _findProduct();
    if (product == null) {
      final body = _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : const _ProductNotFoundView();
      return AppScaffold(title: 'Product', showBackButton: true, body: body);
    }

    final inCart = _controller.cartItems
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (total, item) => total + item.quantity);
    final remaining = product.isAvailable ? product.stockQuantity - inCart : 0;

    return ZivoServiceTheme(
      serviceId: ServiceId.pharmacy,
      child: ProductDetailsView(
        imageUrl: product.imageUrl,
        fallback: Icon(
          Icons.medication_outlined,
          size: 96,
          color: TwColors.textMuted,
        ),
        eyebrow: product.category,
        name: product.name,
        priceLabel: AppMoney.formatCents(product.unitPrice),
        stockLabel: !product.isAvailable
            ? 'Out of stock'
            : product.isLowStock
            ? 'Only ${product.stockQuantity} left'
            : 'In stock',
        isInStock: product.isAvailable,
        description: product.description,
        facts: const ['Over the counter -- no prescription needed.'],
        maxSteps: remaining,
        unavailableLabel: product.isAvailable
            ? 'All stock in cart'
            : 'Out of stock',
        quantityLabel: (steps) => '$steps',
        onAddToCart: (quantity) =>
            unawaited(_addProduct(product, quantity: quantity)),
      ),
    );
  }
}

/// Shown for a cold deep link to a [PharmacyProductDetailsScreen.productId]
/// that no longer resolves in [PharmacyProductDetailsScreen.storeId]'s
/// loaded catalog (e.g. a stale/bad id, or the product was removed) --
/// doesn't crash.
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
