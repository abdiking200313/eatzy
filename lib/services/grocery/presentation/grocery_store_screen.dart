import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';
import 'grocery_product_details_screen.dart';
import 'widgets/grocery_cart_badge_action.dart';
import 'widgets/grocery_product_card.dart';

/// Height of the hero banner's `SliverAppBar.expandedHeight` — matches
/// `RestaurantScreen`'s `_RestaurantAppBar` so this screen reads visually
/// consistent with food's per-restaurant screen (issue #250).
const double _kStoreHeroExtent = 230;

/// A single store's product catalog — reached by tapping a store on
/// [GroceryScreen] (the store list). Mirrors food's
/// "restaurant list -> `RestaurantScreen`" flow: only this store's products
/// are shown, and search here filters by product name rather than by store.
class GroceryStoreScreen extends StatefulWidget {
  const GroceryStoreScreen({super.key, required this.storeId, this.controller});

  final String storeId;
  final GroceryController? controller;

  @override
  State<GroceryStoreScreen> createState() => _GroceryStoreScreenState();
}

class _GroceryStoreScreenState extends State<GroceryStoreScreen> {
  GroceryController get _controller =>
      widget.controller ?? GroceryController.instance;

  final _searchController = TextEditingController();

  late bool _isLoading;
  late bool _hasLoaded;
  late String? _loadError;

  @override
  void initState() {
    super.initState();
    // See GroceryScreen.initState for why the load is kicked off before
    // the first state snapshot is taken. Uses the store-scoped `loadStore`
    // (not `load`) so viewing one store never pulls every other store's
    // catalog too — including on a cold start/deep link straight to this
    // screen, before `GroceryScreen`'s list has loaded anything.
    if ((!_controller.hasLoadedStore(widget.storeId) || _controller.isStale) &&
        !_controller.isLoading) {
      unawaited(_controller.loadStore(widget.storeId));
    }
    _syncLoadState();
    _controller.addListener(_handleControllerChanged);
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
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

  void _handleSearchChanged() => setState(() {});

  void _clearSearch() => _searchController.clear();

  GroceryStore? _findStore() {
    for (final store in _controller.stores) {
      if (store.id == widget.storeId) {
        return store;
      }
    }
    return null;
  }

  List<GroceryProduct> _visibleProducts(GroceryStore store) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return store.products;
    }
    return store.products
        .where((product) => product.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final store = _hasLoaded ? _findStore() : null;
    // The hero banner needs a loaded `GroceryStore` (for its name/photo), so
    // it only appears once loading has actually succeeded — the loading,
    // error, and "not found" states fall back to the plain title bar every
    // other screen in the app uses, same as `RestaurantScreen`'s
    // `_RestaurantLoading`/`_RestaurantError` not showing `_RestaurantHero`
    // either.
    if (store != null) {
      return Scaffold(
        body: _StoreView(
          store: store,
          products: _visibleProducts(store),
          searchController: _searchController,
          onSearchClear: _clearSearch,
          onAdd: _add,
          onOpen: _openDetails,
          onRefresh: () => _controller.loadStore(store.id, forceRefresh: true),
          cartAction: GroceryCartBadgeAction(controller: _controller),
        ),
      );
    }

    return AppScaffold(
      title: 'Store',
      showBackButton: true,
      actions: [GroceryCartBadgeAction(controller: _controller)],
      body: _loadingOrErrorBody(),
    );
  }

  Widget _loadingOrErrorBody() {
    if (_isLoading && !_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError case final error?) {
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
                onPressed: () => _controller.loadStore(widget.storeId),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(TwSpacing.x6),
        child: Text(
          'This store could not be found.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _openDetails(GroceryProduct product) {
    final inCart = _controller.cart
        .where((line) => line.product.id == product.id)
        .fold<double>(0, (total, line) => total + line.quantity);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroceryProductDetailsScreen(
          product: product,
          inCartQuantity: inCart,
          onAddToCart: (steps) => _add(product, steps: steps),
        ),
      ),
    );
  }

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
}

/// The loaded-store body: a hero banner (mirrors `RestaurantScreen`'s
/// `_RestaurantAppBar`) followed by the same area/notice/search header and
/// flat product list this screen has always shown — only the top-of-screen
/// chrome changes here (issue #250).
class _StoreView extends StatelessWidget {
  const _StoreView({
    required this.store,
    required this.products,
    required this.searchController,
    required this.onSearchClear,
    required this.onAdd,
    required this.onOpen,
    required this.onRefresh,
    required this.cartAction,
  });

  final GroceryStore store;
  final List<GroceryProduct> products;
  final TextEditingController searchController;
  final VoidCallback onSearchClear;
  final ValueChanged<GroceryProduct> onAdd;
  final ValueChanged<GroceryProduct> onOpen;
  final Future<void> Function() onRefresh;
  final Widget cartAction;

  @override
  Widget build(BuildContext context) {
    final showEmptyRow = products.isEmpty;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _StoreAppBar(store: store, actions: [cartAction]),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.x5,
              TwSpacing.x5,
              TwSpacing.x5,
              TwSpacing.x2,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.area, style: TwText.textSm),
                  const SizedBox(height: TwSpacing.x2),
                  Text(
                    'Products marked per kg can be added in 0.5 kg steps.',
                    style: TwText.textSm,
                  ),
                  const SizedBox(height: TwSpacing.x5),
                  _StoreSearchField(
                    controller: searchController,
                    onClear: onSearchClear,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.x5,
              0,
              TwSpacing.x5,
              TwSpacing.x8,
            ),
            sliver: showEmptyRow
                ? SliverToBoxAdapter(
                    child: _EmptyProducts(
                      searchQuery: searchController.text.trim(),
                    ),
                  )
                : SliverList.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: TwSpacing.x3),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return GroceryProductCard(
                        product: product,
                        onAdd: () => onAdd(product),
                        onTap: () => onOpen(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The store's product search field, styled to match
/// `PharmacyCatalogScreen`'s `_StoreSearchField`.
class _StoreSearchField extends StatelessWidget {
  const _StoreSearchField({required this.controller, required this.onClear});

  final TextEditingController controller;
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
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search products...',
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

class _StoreAppBar extends StatelessWidget {
  const _StoreAppBar({required this.store, required this.actions});

  final GroceryStore store;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return SliverAppBar(
      pinned: true,
      expandedHeight: _kStoreHeroExtent,
      backgroundColor: palette.accent,
      foregroundColor: palette.onAccent,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.mainApp);
          }
        },
      ),
      title: Text(
        store.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TwText.fontBoldBase.copyWith(color: palette.onAccent),
      ),
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        background: _StoreHero(imageUrl: store.imageUrl ?? ''),
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    // Mirrors `_RestaurantHero`'s decode-size reasoning: the hero fills the
    // SliverAppBar's expandedHeight at full screen width, so the screen
    // width is used as the practical decode bound, scaled
    // for device pixel density and capped at 3x since a wider cap buys no
    // visible sharpness while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    // Only the width is capped: capping both dimensions decodes to that
    // exact box and squashes (stretches) any photo of a different shape.
    final cacheWidth = (MediaQuery.of(context).size.width * cacheScale).round();
    final image = trimmedUrl.isEmpty
        ? const _StoreHeroFallback()
        : CachedNetworkImage(
            imageUrl: trimmedUrl,
            fit: BoxFit.cover,
            memCacheWidth: cacheWidth,
            placeholder: (_, _) => const _StoreHeroFallback(showLoader: true),
            errorWidget: (_, _, _) => const _StoreHeroFallback(),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        // A plain white base under the photo, same as `_RestaurantHero`: a
        // photo with transparent pixels would otherwise reveal whatever
        // sits behind this in the widget tree — the app bar's own accent
        // color — which would read as a stray color bleed-through around
        // the image rather than a clean background.
        const ColoredBox(color: TwColors.card),
        image,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                TwColors.slate900.withOpacityValue(85 / 255),
                TwColors.slate900.withOpacityValue(34 / 255),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreHeroFallback extends StatelessWidget {
  const _StoreHeroFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return ColoredBox(
      color: TwColors.card,
      child: Center(
        child: showLoader
            ? CircularProgressIndicator(color: palette.accent)
            : Icon(Icons.storefront_rounded, color: palette.accent, size: 72),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TwSpacing.x8),
      child: Center(
        child: Text(
          searchQuery.isEmpty
              ? 'This store has no products yet.'
              : 'No products match "$searchQuery".',
          textAlign: TextAlign.center,
          style: TwText.textSm,
        ),
      ),
    );
  }
}
