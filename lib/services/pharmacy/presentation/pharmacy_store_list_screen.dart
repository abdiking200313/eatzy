import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
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
    context.push(
      Uri(
        path: AppRoutes.pharmacyStoreDetails(store.id),
        queryParameters: {'name': store.name},
      ).toString(),
    );
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

  Widget _buildContent(List<PharmacyStore> stores) {
    return ListView(
      padding: const EdgeInsets.all(TwSpacing.x5),
      physics: const AlwaysScrollableScrollPhysics(),
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
        const SizedBox(height: TwSpacing.rhythmSection),
        Text('Pharmacies near you', style: TwText.textXl),
        const SizedBox(height: TwSpacing.rhythmDefault),
        _filteredStores == null
            ? _buildStoreList(stores)
            : _buildFilteredStoreList(_filteredStores!),
      ],
    );
  }

  Widget _buildStoreList(List<PharmacyStore> stores) {
    if (stores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(TwSpacing.x8),
        child: Center(child: Text('No pharmacies found.')),
      );
    }
    return Column(children: [for (final store in stores) _buildStore(store)]);
  }

  Widget _buildFilteredStoreList(Future<List<PharmacyStore>> future) {
    return FutureBuilder<List<PharmacyStore>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(TwSpacing.x8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(TwSpacing.x8),
            child: Center(child: Text('Pharmacies could not be loaded.')),
          );
        }

        final stores = snapshot.data ?? const <PharmacyStore>[];
        if (stores.isEmpty) {
          final searchQuery = _searchController.text.trim();
          return Padding(
            padding: const EdgeInsets.all(TwSpacing.x8),
            child: Center(child: Text('No pharmacies match "$searchQuery".')),
          );
        }

        return Column(
          children: [for (final store in stores) _buildStore(store)],
        );
      },
    );
  }

  Widget _buildStore(PharmacyStore store) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x4),
      child: _StoreCard(store: store, onPressed: () => _openStore(store)),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store, required this.onPressed});

  final PharmacyStore store;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // White card only — the per-service accent is confined to the icon chip.
    return OutlinedCard(
      onTap: onPressed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceIconChip(icon: Icons.local_pharmacy_outlined),
          const SizedBox(width: TwSpacing.rhythmDefault),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.fontBoldBase,
                ),
                if (store.address.isNotEmpty) ...[
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Text(
                    store.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TwText.textSm.copyWith(color: TwColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: TwSpacing.x2),
          const Icon(Icons.chevron_right_rounded, color: TwColors.textMuted),
        ],
      ),
    );
  }
}

/// Isolated so a cart mutation elsewhere doesn't rebuild the (potentially
/// long) store list above it. Mirrors `PharmacyCatalogScreen`'s
/// `_CartAction`.
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
