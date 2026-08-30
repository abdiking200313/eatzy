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
import '../../../widgets/cart_app_bar_action.dart';
import '../models/pharmacy_product.dart';
import 'pharmacy_controller.dart';

/// How long to wait after the last keystroke before running a search query,
/// so typing quickly doesn't fire a request per character. Mirrors
/// `FoodHomeScreen`'s `_searchDebounce`.
const Duration _searchDebounce = Duration(milliseconds: 400);

/// A single pharmacy's OTC product catalog — reached by picking a pharmacy
/// on [PharmacyStoreListScreen] first, so browsing (and the cart it feeds)
/// is always scoped to one pharmacy at a time (issue #141). The pharmacy
/// counterpart of `RestaurantScreen`.
class PharmacyCatalogScreen extends StatefulWidget {
  const PharmacyCatalogScreen({
    super.key,
    required this.storeId,
    this.storeName,
    this.controller,
  });

  /// The pharmacy (`PharmacyStore.id`) this catalog is scoped to.
  final String storeId;

  /// The pharmacy's display name, passed through from the store list (the
  /// same "pass the name via the calling screen" shape as
  /// `FoodExploreScreen`'s `categoryName`) so the app bar title doesn't need
  /// its own fetch just to show it. Falls back to a generic title when
  /// absent (e.g. a bare deep link to this route).
  final String? storeName;

  final PharmacyController? controller;

  @override
  State<PharmacyCatalogScreen> createState() => _PharmacyCatalogScreenState();
}

class _PharmacyCatalogScreenState extends State<PharmacyCatalogScreen> {
  PharmacyController get _controller =>
      widget.controller ?? PharmacyController.instance;

  final _searchController = TextEditingController();
  Timer? _debounce;

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
    _loadStore();
  }

  @override
  void didUpdateWidget(covariant PharmacyCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeId != widget.storeId ||
        oldWidget.controller != widget.controller) {
      _searchController.clear();
      _loadStore();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _loadStore() {
    // Kick off the load first: its synchronous prefix (setting `isLoading`
    // and calling `notifyListeners()`) runs immediately, before the first
    // `await`. Snapshotting state after that call — rather than listening
    // first — means our own `setState` only ever runs in response to a
    // later, async notification, never re-entrantly during this
    // `initState()`/first-build pass.
    unawaited(_controller.loadProducts(storeId: widget.storeId));
    _syncLoadState();
    _controller.addListener(_handleControllerChanged);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      unawaited(
        _controller.loadProducts(
          storeId: widget.storeId,
          searchQuery: _searchController.text,
          forceRefresh: true,
        ),
      );
    });
    // Show/hide the clear button immediately without waiting on the debounce.
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    unawaited(
      _controller.loadProducts(storeId: widget.storeId, forceRefresh: true),
    );
    setState(() {});
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
      title: widget.storeName ?? 'Pharmacy',
      showBackButton: true,
      actions: [
        _CartAction(
          controller: _controller,
          onPressed: () => context.push(AppRoutes.pharmacyCart),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _productCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _productCount == 0) {
      return _CatalogError(message: _loadError!, onRetry: _retry);
    }

    // 3 fixed header rows (search field + notice + heading block) + one row
    // per product + an optional trailing "load more" row, or (once loaded)
    // one "no products" row in place of both when the store/search scope
    // has nothing to show.
    final showEmptyRow = !_isLoading && _productCount == 0;
    final itemCount =
        3 + _productCount + (_hasMore ? 1 : 0) + (showEmptyRow ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => _controller.loadProducts(
        storeId: widget.storeId,
        searchQuery: _searchController.text,
        forceRefresh: true,
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(TwSpacing.x5),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: TwSpacing.rhythmDefault),
              child: _StoreSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
            );
          }
          if (index == 1) {
            return const Padding(
              padding: EdgeInsets.only(bottom: TwSpacing.rhythmDefault),
              child: _OtcNotice(),
            );
          }
          if (index == 2) {
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

          final productIndex = index - 3;
          if (showEmptyRow && productIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: TwSpacing.x8),
              child: Center(child: Text(_emptyMessage())),
            );
          }
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

  void _retry() {
    unawaited(_controller.loadProducts(storeId: widget.storeId));
  }

  String _emptyMessage() {
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      return 'No products match "$searchQuery" at this pharmacy.';
    }
    return 'This pharmacy has no OTC products yet.';
  }

  Future<void> _addProduct(PharmacyProduct product) async {
    var result = _controller.addProduct(product);

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
      result = _controller.addProduct(product, replaceStoreCart: true);
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
}

/// A pill-shaped search field scoped to this pharmacy's catalog, styled to
/// match `FoodHomeScreen`'s restaurant search box.
class _StoreSearchField extends StatelessWidget {
  const _StoreSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: TwColors.card,
      borderColor: TwColors.border,
      borderRadius: 50,
      child: Row(
        children: [
          const Icon(Icons.search, color: TwColors.textMuted),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search this pharmacy...',
                hintStyle: TextStyle(color: TwColors.textMuted),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(left: TwSpacing.x2),
                child: Icon(Icons.clear, size: 20, color: TwColors.textMuted),
              ),
            ),
        ],
      ),
    );
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
        return CartAppBarAction(
          key: const ValueKey('pharmacy-cart-action'),
          itemCount: itemCount,
          tooltip: 'Pharmacy cart',
          onPressed: onPressed,
          icon: Icons.shopping_bag_rounded,
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
