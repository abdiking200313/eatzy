import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/cart_app_bar_action.dart';
import '../../../widgets/store_row_card.dart';
import '../data/pharmacy_repository.dart';
import '../models/pharmacy_store.dart';
import 'pharmacy_controller.dart';

typedef PharmacyStoreLoader = Future<List<PharmacyStore>> Function();

/// Runs a server-side name search over pharmacies. Defaults to
/// [PharmacyStoreRepository.fetchStores]; overridable in tests the same way
/// [PharmacyStoreLoader] is. Mirrors `RestaurantQuery`.
typedef PharmacyStoreQuery =
    Future<List<PharmacyStore>> Function({String? searchQuery});

/// How long to wait after the last keystroke before running a search query,
/// so typing quickly doesn't fire a request per character. Mirrors
/// `FoodHomeScreen`'s `_searchDebounce`.
const Duration _searchDebounce = Duration(milliseconds: 400);

/// The pharmacy vertical's entry screen: a searchable list of pharmacies a
/// customer picks from before browsing a single pharmacy's OTC catalog
/// (issue #141) — the pharmacy counterpart of `FoodHomeScreen`'s restaurant
/// list.
class PharmacyStoreListScreen extends StatefulWidget {
  const PharmacyStoreListScreen({
    super.key,
    this.storeLoader,
    this.storeQuery,
    this.controller,
  });

  final PharmacyStoreLoader? storeLoader;
  final PharmacyStoreQuery? storeQuery;

  /// The cart-owning controller the badge in the app bar reads from.
  /// Injectable the same way `PharmacyCatalogScreen.controller` is, so a
  /// widget test never has to touch `PharmacyController.instance` (which
  /// requires a live Supabase client).
  final PharmacyController? controller;

  @override
  State<PharmacyStoreListScreen> createState() =>
      _PharmacyStoreListScreenState();
}

class _PharmacyStoreListScreenState extends State<PharmacyStoreListScreen> {
  PharmacyController get _controller =>
      widget.controller ?? PharmacyController.instance;

  late Future<List<PharmacyStore>> _storesFuture;
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Non-null once a search term has been entered — replaces the unfiltered
  /// `_storesFuture` list in the results section below until cleared.
  Future<List<PharmacyStore>>? _filteredStores;

  @override
  void initState() {
    super.initState();
    _storesFuture = _loadStores();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<PharmacyStore>> _loadStores() {
    return widget.storeLoader?.call() ?? _defaultQuery();
  }

  Future<List<PharmacyStore>> _defaultQuery({String? searchQuery}) {
    return SupabasePharmacyStoreRepository(
      client: Supabase.instance.client,
    ).fetchStores(searchQuery: searchQuery);
  }

  void _retry() {
    setState(() {
      _storesFuture = _loadStores();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _filteredStores = _buildFilteredStores();
      });
    });
    // Show/hide the clear button immediately without waiting on the debounce.
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _filteredStores = _buildFilteredStores();
    });
  }

  /// Builds the filtered store future for the current search text, or
  /// `null` when the search box is empty (meaning the unfiltered
  /// `_storesFuture` list should be shown instead).
  Future<List<PharmacyStore>>? _buildFilteredStores() {
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) {
      return null;
    }
    final query = widget.storeQuery ?? _defaultQuery;
    return query(searchQuery: searchQuery);
  }

  void _openStore(PharmacyStore store) {
    // `photoUrl` is forwarded the same way `name` is, for
    // `PharmacyCatalogScreen`'s hero banner (issue #250) — see the TODO on
    // `PharmacyCatalogScreen.storeImageUrl` for the corresponding
    // `app_router.dart` read this still needs.
    context.push(
      Uri(
        path: AppRoutes.pharmacyStoreDetails(store.id),
        queryParameters: {
          'name': store.name,
          if (store.imageUrl != null) 'photoUrl': store.imageUrl,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pharmacy',
      showBackButton: true,
      actions: [
        CartBadgeAction(
          key: const ValueKey('pharmacy-cart-action'),
          listenable: _controller,
          itemCount: () => _controller.itemCount,
          icon: Icons.shopping_bag_rounded,
          tooltip: (_) => 'Pharmacy cart',
          route: AppRoutes.pharmacyCart,
        ),
      ],
      body: FutureBuilder<List<PharmacyStore>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StoreListError(onRetry: _retry);
          }
          return _buildContent(snapshot.requireData);
        },
      ),
    );
  }

  // Two slivers: a fixed header (search field + heading) and the store rows
  // themselves, the latter built lazily via `SliverList.builder` (rather
  // than eagerly as a `Column` of every row up front) so a large pharmacy
  // list only builds the rows actually on/near screen — see issue #177.
  // `_buildStoreList`/`_buildFilteredStoreList` each return a sliver, which
  // is why they can sit directly in `CustomScrollView.slivers` even wrapped
  // in a `FutureBuilder` (its `builder` result — a sliver — is exactly what
  // `FutureBuilder.build` returns, with no intervening box wrapper).
  Widget _buildContent(List<PharmacyStore> stores) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.x5,
            TwSpacing.x5,
            TwSpacing.x5,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedCard(
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
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search pharmacies...',
                            hintStyle: TextStyle(color: TwColors.textMuted),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: _clearSearch,
                          child: const Padding(
                            padding: EdgeInsets.only(left: TwSpacing.x2),
                            child: Icon(
                              Icons.clear,
                              size: 20,
                              color: TwColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: TwSpacing.sectionGap),
                Text('Pharmacies near you', style: TwText.textXl),
                const SizedBox(height: TwSpacing.x3_5),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.x5,
            0,
            TwSpacing.x5,
            TwSpacing.x5,
          ),
          sliver: _filteredStores == null
              ? _buildStoreList(stores)
              : _buildFilteredStoreList(_filteredStores!),
        ),
      ],
    );
  }

  Widget _buildStoreList(List<PharmacyStore> stores) {
    if (stores.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(TwSpacing.x8),
          child: Center(child: Text('No pharmacies found.')),
        ),
      );
    }
    return SliverList.builder(
      itemCount: stores.length,
      itemBuilder: (context, index) => _buildStore(stores[index]),
    );
  }

  Widget _buildFilteredStoreList(Future<List<PharmacyStore>> future) {
    return FutureBuilder<List<PharmacyStore>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(TwSpacing.x8),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(TwSpacing.x8),
              child: Center(child: Text('Pharmacies could not be loaded.')),
            ),
          );
        }

        final stores = snapshot.data ?? const <PharmacyStore>[];
        if (stores.isEmpty) {
          final searchQuery = _searchController.text.trim();
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x8),
              child: Center(child: Text('No pharmacies match "$searchQuery".')),
            ),
          );
        }

        return SliverList.builder(
          itemCount: stores.length,
          itemBuilder: (context, index) => _buildStore(stores[index]),
        );
      },
    );
  }

  Widget _buildStore(PharmacyStore store) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x4),
      child: StoreRowCard(
        imageUrl: store.imageUrl,
        fallbackIcon: Icons.local_pharmacy_outlined,
        name: store.name,
        subtitleLines: [if (store.address.isNotEmpty) store.address],
        subtitleMaxLines: 2,
        onTap: () => _openStore(store),
      ),
    );
  }
}

class _StoreListError extends StatelessWidget {
  const _StoreListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: OutlinedCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: context.serviceColors.accent,
              ),
              const SizedBox(height: TwSpacing.x2),
              const Text('Pharmacies could not be loaded.'),
              const SizedBox(height: TwSpacing.x4),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
