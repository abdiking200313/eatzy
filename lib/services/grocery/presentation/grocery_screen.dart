import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/cart_app_bar_action.dart';
import '../../../widgets/store_row_card.dart';
import '../models/grocery_models.dart';
import 'grocery_controller.dart';

/// The grocery store list: pick a store first, then browse just that
/// store's products — mirroring food's "restaurant list -> restaurant
/// menu" flow instead of the old flattened, every-store-at-once feed.
class GroceryScreen extends StatefulWidget {
  const GroceryScreen({
    super.key,
    this.controller,
    this.storeType = GroceryStoreType.grocery,
  });

  final GroceryController? controller;

  /// Which category this list shows. Fresh Meat and Electronics reuse this
  /// screen (and the whole grocery engine) filtered to their store type.
  final GroceryStoreType storeType;

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  GroceryController get _controller =>
      widget.controller ?? GroceryController.forType(widget.storeType);

  final _searchController = TextEditingController();

  // Mirrors only the load-relevant slice of the controller's state. Cart
  // mutations (`addProduct`) also call `notifyListeners()` on the same
  // controller, but never change any of these fields, so
  // `_handleControllerChanged` skips `setState` for them — only the cart
  // badge below listens for those directly.
  late bool _isLoading;
  late bool _hasLoaded;
  late String? _loadError;
  late int _storeCount;

  @override
  void initState() {
    super.initState();
    // Kick off the load first: if it actually starts, its synchronous
    // prefix (setting `isLoading` and calling `notifyListeners()`) runs
    // immediately, before the first `await`. Snapshotting state after
    // that call — rather than listening first — means our own `setState`
    // only ever runs in response to a later, async notification, never
    // re-entrantly during this `initState()`/first-build pass.
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
    _storeCount = _controller.stores.length;
  }

  void _handleControllerChanged() {
    final isLoading = _controller.isLoading;
    final hasLoaded = _controller.hasLoaded;
    final loadError = _controller.loadError;
    final storeCount = _controller.stores.length;
    if (isLoading == _isLoading &&
        hasLoaded == _hasLoaded &&
        loadError == _loadError &&
        storeCount == _storeCount) {
      return;
    }
    setState(() {
      _isLoading = isLoading;
      _hasLoaded = hasLoaded;
      _loadError = loadError;
      _storeCount = storeCount;
    });
  }

  void _handleSearchChanged() => setState(() {});

  void _clearSearch() => _searchController.clear();

  List<GroceryStore> _visibleStores() {
    final query = _searchController.text.trim().toLowerCase();
    return _controller.stores
        .where(
          (store) => query.isEmpty || store.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _openStore(GroceryStore store) =>
      context.push(widget.storeType.storeDetailsRoute(store.id));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.storeType.title,
      showBackButton: true,
      actions: [
        CartBadgeAction(
          listenable: _controller,
          itemCount: () => _controller.itemCount,
          icon: Icons.shopping_basket_rounded,
          tooltip: (count) => '${widget.storeType.serviceName} cart ($count)',
          route: widget.storeType.cartRoute,
        ),
      ],
      body: _body(),
    );
  }

  Widget _body() {
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

    final stores = _visibleStores();
    // One fixed header row (heading/blurb/search field) + one row per store,
    // or (once loaded) one "no stores" row in place of the store rows when
    // the search has nothing to show. Flattened into a single
    // `ListView.builder` (rather than building every store row eagerly) so
    // a large store list only builds the rows actually on/near screen —
    // see issue #177.
    final showEmptyRow = stores.isEmpty;
    final itemCount = 1 + (showEmptyRow ? 1 : stores.length);

    return RefreshIndicator(
      onRefresh: () => _controller.load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          TwSpacing.x5,
          TwSpacing.x2,
          TwSpacing.x5,
          TwSpacing.x8,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: TwSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Somali stores near you', style: TwText.textXl),
                  const SizedBox(height: TwSpacing.x2),
                  Text(
                    'Pick a store to browse its products.',
                    style: TwText.textSm,
                  ),
                  const SizedBox(height: TwSpacing.x5),
                  _searchField(),
                ],
              ),
            );
          }

          if (showEmptyRow) {
            return _EmptyStores(
              searchQuery: _searchController.text.trim(),
              storesNoun: widget.storeType.storesNoun,
            );
          }

          final store = stores[index - 1];
          final productCount = store.products.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: TwSpacing.x3),
            child: StoreRowCard(
              imageUrl: store.imageUrl,
              fallbackIcon: Icons.storefront_rounded,
              name: store.name,
              subtitleLines: [store.area],
              caption:
                  '$productCount ${productCount == 1 ? 'product' : 'products'}',
              onTap: () => _openStore(store),
            ),
          );
        },
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
                hintText: 'Search stores...',
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
}

class _EmptyStores extends StatelessWidget {
  const _EmptyStores({required this.searchQuery, required this.storesNoun});

  final String searchQuery;
  final String storesNoun;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TwSpacing.x8),
      child: Center(
        child: Text(
          searchQuery.isEmpty
              ? 'No $storesNoun found yet.'
              : 'No stores match "$searchQuery".',
          textAlign: TextAlign.center,
          style: TwText.textSm,
        ),
      ),
    );
  }
}
