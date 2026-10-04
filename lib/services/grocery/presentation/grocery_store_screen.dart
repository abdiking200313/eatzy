import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/cart_app_bar_action.dart';
import '../../../widgets/store_hero_app_bar.dart';
import '../../../widgets/app_search_bar.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';
import 'widgets/grocery_product_card.dart';

/// A single store's product catalog — reached by tapping a store on
/// [GroceryScreen] (the store list). Mirrors food's
/// "restaurant list -> `RestaurantScreen`" flow: only this store's products
/// are shown, and search here filters by product name rather than by store.
class GroceryStoreScreen extends StatefulWidget {
  const GroceryStoreScreen({
    super.key,
    required this.storeId,
    this.controller,
    this.storeType = GroceryStoreType.grocery,
  });

  final String storeId;
  final GroceryController? controller;

  /// Which category's cart this store adds to.
  final GroceryStoreType storeType;

  @override
  State<GroceryStoreScreen> createState() => _GroceryStoreScreenState();
}

class _GroceryStoreScreenState extends State<GroceryStoreScreen> {
  /// Resolved once in [didChangeDependencies] (never reassigned after) —
  /// see `GroceryScreen._resolvedController` for why this can't happen in
  /// `initState`.
  GroceryController? _resolvedController;
  GroceryController get _controller =>
      widget.controller ?? _resolvedController!;

  final _searchController = TextEditingController();

  late bool _isLoading;
  late bool _hasLoaded;
  late String? _loadError;

  bool _didInitializeController = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

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

    // See GroceryScreen.didChangeDependencies for why the load is kicked
    // off before the first state snapshot is taken. Uses the store-scoped
    // `loadStore` (not `load`) so viewing one store never pulls every other
    // store's catalog too — including on a cold start/deep link straight to
    // this screen, before `GroceryScreen`'s list has loaded anything.
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
    // `_RestaurantLoading`/`_RestaurantError` not showing `StoreHeroAppBar`
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
          cartAction: _cartAction(),
        ),
      );
    }

    return AppScaffold(
      title: 'Store',
      showBackButton: true,
      actions: [_cartAction()],
      body: _loadingOrErrorBody(),
    );
  }

  Widget _cartAction() {
    return CartBadgeAction(
      listenable: _controller,
      itemCount: () => _controller.itemCount,
      icon: Icons.shopping_basket_rounded,
      tooltip: (count) => '${widget.storeType.serviceName} cart ($count)',
      route: widget.storeType.cartRoute,
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
    context.push(_productDetailsRoute(widget.storeId, product.id));
  }

  /// `AppRoutes.groceryProductDetails`'s per-[GroceryStoreType] siblings --
  /// mirrors `GroceryStoreType.storeRoutePattern`'s own
  /// grocery/freshMeat/electronics split, since this screen (and its
  /// product-details destination) is shared across all three store types,
  /// each with its own URL prefix (issue #288).
  String _productDetailsRoute(String storeId, String productId) =>
      switch (widget.storeType) {
        GroceryStoreType.grocery => AppRoutes.groceryProductDetails(
          storeId,
          productId,
        ),
        GroceryStoreType.freshMeat => AppRoutes.freshMeatProductDetails(
          storeId,
          productId,
        ),
        GroceryStoreType.electronics => AppRoutes.electronicsProductDetails(
          storeId,
          productId,
        ),
      };

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

/// Groups [products] into category sections, like `RestaurantScreen`'s menu:
/// sections ordered by `grocery_categories.sort_order` (then name), with
/// uncategorised products last under "Other". Products keep their incoming
/// order (by name, from the repository) within a section.
@visibleForTesting
List<({String name, List<GroceryProduct> products})> groupByCategory(
  List<GroceryProduct> products,
) {
  final groups = <String?, List<GroceryProduct>>{};
  for (final product in products) {
    groups.putIfAbsent(product.categoryName, () => []).add(product);
  }
  final entries = groups.entries.toList()
    ..sort((a, b) {
      if (a.key == null || b.key == null) {
        return (a.key == null ? 1 : 0) - (b.key == null ? 1 : 0);
      }
      final bySortOrder = a.value.first.categorySortOrder.compareTo(
        b.value.first.categorySortOrder,
      );
      return bySortOrder != 0 ? bySortOrder : a.key!.compareTo(b.key!);
    });
  return [
    for (final entry in entries)
      (name: entry.key ?? 'Other', products: entry.value),
  ];
}

/// The loaded-store body: a hero banner (shared `StoreHeroAppBar`) followed
/// by the area/notice/search header and the store's products grouped into
/// category sections.
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
    final sections = groupByCategory(products);
    // A lone section (an uncategorised store, or a search that only matches
    // one category) needs no header — the list then looks as it did before
    // categories existed.
    final showSectionHeaders = sections.length > 1;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          StoreHeroAppBar(
            title: store.name,
            imageUrl: store.imageUrl,
            fallbackIcon: Icons.storefront_rounded,
            showBackButton: true,
            actions: [cartAction],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.screenX,
              TwSpacing.screenX,
              TwSpacing.screenX,
              0,
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
                  AppSearchBar(
                    controller: searchController,
                    hintText: 'Search products...',
                    onClear: onSearchClear,
                  ),
                ],
              ),
            ),
          ),
          if (showEmptyRow)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: TwSpacing.screenX,
              ),
              sliver: SliverToBoxAdapter(
                child: _EmptyProducts(
                  searchQuery: searchController.text.trim(),
                ),
              ),
            )
          else
            for (final section in sections) ...[
              if (!showSectionHeaders)
                const SliverToBoxAdapter(
                  child: SizedBox(height: TwSpacing.headerToContent),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    TwSpacing.screenX,
                    TwSpacing.sectionGap,
                    TwSpacing.screenX,
                    TwSpacing.headerToContent,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(section.name, style: TwText.sectionTitle),
                        ),
                        Text(
                          '${section.products.length} '
                          '${section.products.length == 1 ? 'item' : 'items'}',
                          style: TwText.textXs.copyWith(
                            color: TwColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TwSpacing.screenX,
                ),
                sliver: SliverList.separated(
                  itemCount: section.products.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: TwSpacing.x3),
                  itemBuilder: (context, index) {
                    final product = section.products[index];
                    return GroceryProductCard(
                      product: product,
                      onAdd: () => onAdd(product),
                      onTap: () => onOpen(product),
                    );
                  },
                ),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x6)),
        ],
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
