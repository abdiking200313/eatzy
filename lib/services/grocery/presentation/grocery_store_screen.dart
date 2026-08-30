import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';
import 'widgets/grocery_cart_badge_action.dart';
import 'widgets/grocery_product_card.dart';

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
    // the first state snapshot is taken.
    if ((!_controller.hasLoaded || _controller.isStale) &&
        !_controller.isLoading) {
      unawaited(_controller.load());
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
    _hasLoaded = _controller.hasLoaded;
    _loadError = _controller.loadError;
  }

  void _handleControllerChanged() {
    final isLoading = _controller.isLoading;
    final hasLoaded = _controller.hasLoaded;
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
    return AppScaffold(
      title: store?.name ?? 'Store',
      showBackButton: true,
      actions: [GroceryCartBadgeAction(controller: _controller)],
      body: _body(store),
    );
  }

  Widget _body(GroceryStore? store) {
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
                onPressed: _controller.load,
              ),
            ],
          ),
        ),
      );
    }

    if (store == null) {
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

    final products = _visibleProducts(store);

    return RefreshIndicator(
      onRefresh: () => _controller.load(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          TwSpacing.x5,
          TwSpacing.x2,
          TwSpacing.x5,
          TwSpacing.x8,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(store.area, style: TwText.textSm),
          const SizedBox(height: TwSpacing.x2),
          Text(
            'Products marked per kg can be added in 0.5 kg steps.',
            style: TwText.textSm,
          ),
          const SizedBox(height: TwSpacing.x5),
          _searchField(),
          const SizedBox(height: TwSpacing.x5),
          if (products.isEmpty)
            _EmptyProducts(searchQuery: _searchController.text.trim())
          else
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: TwSpacing.x3),
                child: GroceryProductCard(
                  product: product,
                  onAdd: () => _add(product),
                ),
              ),
        ],
      ),
    );
  }

  Widget _searchField() {
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
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search products...',
                hintStyle: TextStyle(color: TwColors.textMuted),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: const Padding(
                padding: EdgeInsets.only(left: TwSpacing.x2),
                child: Icon(Icons.clear, size: 20, color: TwColors.textMuted),
              ),
            ),
        ],
      ),
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
    showCartSnackBar(context, message);
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
