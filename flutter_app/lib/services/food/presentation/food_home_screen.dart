import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../platform/cache/catalog_queries.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/cart_app_bar_action.dart';
import '../../../widgets/store_row_card.dart';
import '../data/category_repository.dart';
import '../data/restaurant_repository.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import 'cart_controller.dart';
import 'widgets/categories_section.dart';
import 'widgets/section_header.dart';

typedef CategoryLoader = Future<List<Category>> Function();
typedef RestaurantLoader = Future<List<Restaurant>> Function();

/// Runs a server-side search/category-filtered restaurant query. Defaults to
/// [RestaurantRepository.fetchRestaurants]; overridable in tests the same
/// way [RestaurantLoader]/[CategoryLoader] are.
typedef RestaurantQuery =
    Future<List<Restaurant>> Function({
      String? searchQuery,
      String? categoryId,
    });

/// How long to wait after the last keystroke before running a search query,
/// so typing quickly doesn't fire a request per character.
const Duration _searchDebounce = Duration(milliseconds: 400);

class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({
    super.key,
    this.categoryLoader,
    this.restaurantLoader,
    this.restaurantQuery,
  });

  final CategoryLoader? categoryLoader;
  final RestaurantLoader? restaurantLoader;
  final RestaurantQuery? restaurantQuery;

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  late Stream<FoodHomeData> _home;

  /// The cached data shown on the first frame, before [_home] emits.
  FoodHomeData? _initialHome;
  String? _selectedCategoryId;
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Non-null once a category is selected or a search term has been
  /// submitted — replaces the unfiltered `data.restaurants` list in the
  /// results section below until cleared.
  Future<List<Restaurant>>? _filteredRestaurants;

  @override
  void initState() {
    super.initState();
    _startHome();
  }

  /// Injected loaders (tests) bypass the cache; the real app goes through
  /// [CatalogQueries.foodHome], which shows the last-known data instantly
  /// and refreshes it in the background.
  void _startHome() {
    if (widget.categoryLoader != null || widget.restaurantLoader != null) {
      _initialHome = null;
      _home = Stream.fromFuture(_loadHome());
      return;
    }
    final query = CatalogQueries.foodHome();
    _initialHome = query.peek();
    _home = query.watch().map((data) {
      CatalogQueries.prefetchMenus(data.restaurants);
      return data;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<FoodHomeData> _loadHome() async {
    final categoriesFuture =
        widget.categoryLoader?.call() ?? CategoryRepository().fetchCategories();
    final restaurantsFuture =
        widget.restaurantLoader?.call() ??
        RestaurantRepository().fetchRestaurants();
    final (categories, restaurants) = await (
      categoriesFuture,
      restaurantsFuture,
    ).wait;

    return (categories: categories, restaurants: restaurants);
  }

  void _retry() {
    setState(_startHome);
  }

  void _selectCategory(String categoryId) {
    setState(() {
      // Tapping the already-selected chip clears the filter.
      _selectedCategoryId = _selectedCategoryId == categoryId
          ? null
          : categoryId;
      _filteredRestaurants = _buildFilteredRestaurants();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _filteredRestaurants = _buildFilteredRestaurants();
      });
    });
    // Show/hide the clear button immediately without waiting on the debounce.
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _filteredRestaurants = _buildFilteredRestaurants());
  }

  /// Builds the filtered restaurant future for the current search text and
  /// selected category, or `null` when neither filter is active (meaning the
  /// unfiltered `data.restaurants` list should be shown instead).
  Future<List<Restaurant>>? _buildFilteredRestaurants() {
    final categoryId = _selectedCategoryId;
    final searchQuery = _searchController.text.trim();
    if (categoryId == null && searchQuery.isEmpty) {
      return null;
    }
    final query =
        widget.restaurantQuery ?? RestaurantRepository().fetchRestaurants;
    return query(
      searchQuery: searchQuery.isEmpty ? null : searchQuery,
      categoryId: categoryId,
    );
  }

  void _openCategories() => context.push(AppRoutes.foodCategories);

  void _openExplore() => context.push(AppRoutes.foodExplore);

  void _openRestaurant(Restaurant restaurant) =>
      context.push(AppRoutes.restaurantDetails(restaurant.id));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Food',
      showBackButton: true,
      actions: [
        AnimatedBuilder(
          animation: CartController.instance,
          builder: (context, _) {
            final count = CartController.instance.itemCount;
            return CartAppBarAction(
              itemCount: count,
              tooltip: 'Food cart ($count)',
              onPressed: () => context.push(AppRoutes.foodCart),
              icon: Icons.shopping_cart_rounded,
            );
          },
        ),
      ],
      body: StreamBuilder<FoodHomeData>(
        stream: _home,
        initialData: _initialHome,
        builder: (context, snapshot) {
          // Cached data wins over both the spinner and a failed background
          // refresh; the error card only shows when nothing was cached.
          final data = snapshot.data;
          if (data != null) {
            return _buildHomeContent(data);
          }
          if (snapshot.hasError) {
            return _FoodHomeError(onRetry: _retry);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildHomeContent(FoodHomeData data) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TwSpacing.screenX,
                  18,
                  TwSpacing.screenX,
                  0,
                ),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: 'Search restaurants...',
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
              ),
              const SizedBox(height: TwSpacing.sectionGapDense),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TwSpacing.screenX,
                ),
                child: SectionHeader(
                  title: 'Categories',
                  actionLabel: 'See All',
                  onPressed: _openCategories,
                ),
              ),
              const SizedBox(height: TwSpacing.headerToContent),
              // Edge-to-edge horizontal rail: no outer padding clips it, the
              // inset instead comes from the rail's own ListView padding.
              CategoriesSection(
                categories: data.categories,
                selectedCategoryId: _selectedCategoryId,
                onCategorySelected: _selectCategory,
              ),
              const SizedBox(height: TwSpacing.sectionGapDense),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TwSpacing.screenX,
                ),
                child: SectionHeader(
                  title: 'Trending Now',
                  actionLabel: 'View All',
                  onPressed: _openExplore,
                ),
              ),
              const SizedBox(height: TwSpacing.headerToContent),
            ],
          ),
        ),
        _filteredRestaurants == null
            ? _buildRestaurantResults(data.restaurants)
            : _buildFilteredRestaurantResults(_filteredRestaurants!),
        const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x6)),
      ],
    );
  }

  /// Results for the default, unfiltered home view.
  Widget _buildRestaurantResults(List<Restaurant> restaurants) {
    if (restaurants.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(TwSpacing.x8),
          child: Center(child: Text('No restaurants found.')),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: TwSpacing.screenX),
      sliver: SliverList.builder(
        itemCount: restaurants.length,
        itemBuilder: (context, index) =>
            _buildRestaurant(context, restaurants[index]),
      ),
    );
  }

  /// Results while a category and/or a search term is active, resolved
  /// server-side via [RestaurantRepository.fetchRestaurants].
  Widget _buildFilteredRestaurantResults(Future<List<Restaurant>> future) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<Restaurant>>(
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
              child: Center(child: Text('Restaurants could not be loaded.')),
            );
          }

          final restaurants = snapshot.data ?? const <Restaurant>[];
          if (restaurants.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(TwSpacing.x8),
              child: Center(child: Text(_emptyFilterMessage())),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.screenX),
            child: Column(
              children: [
                for (final restaurant in restaurants)
                  _buildRestaurant(context, restaurant),
              ],
            ),
          );
        },
      ),
    );
  }

  String _emptyFilterMessage() {
    final searchQuery = _searchController.text.trim();
    final hasCategory = _selectedCategoryId != null;
    if (searchQuery.isNotEmpty && hasCategory) {
      return 'No restaurants match "$searchQuery" in this category.';
    }
    if (searchQuery.isNotEmpty) {
      return 'No restaurants match "$searchQuery".';
    }
    return 'No restaurants found in this category.';
  }

  Widget _buildRestaurant(BuildContext context, Restaurant restaurant) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x4),
      child: StoreRowCard(
        imageUrl: restaurant.logoUrl,
        fallbackIcon: Icons.restaurant_rounded,
        name: restaurant.name,
        subtitleLines: [
          if (restaurant.description.trim().isNotEmpty) restaurant.description,
        ],
        onTap: () => _openRestaurant(restaurant),
      ),
    );
  }
}

class _FoodHomeError extends StatelessWidget {
  const _FoodHomeError({required this.onRetry});

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
              const Text('Food options could not be loaded.'),
              const SizedBox(height: TwSpacing.x4),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
