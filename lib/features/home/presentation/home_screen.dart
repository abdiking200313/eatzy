import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/zivo_logo.dart';
import '../data/category_repository.dart';
import '../data/restaurant_repository.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import 'widgets/categories_section.dart';
import 'widgets/restaurant_card.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.categoryLoader,
    this.restaurantLoader,
    this.restaurantQuery,
  });

  final CategoryLoader? categoryLoader;
  final RestaurantLoader? restaurantLoader;
  final RestaurantQuery? restaurantQuery;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_FoodHomeData> _homeFuture;
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
    _homeFuture = _loadHome();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<_FoodHomeData> _loadHome() async {
    final categoriesFuture =
        widget.categoryLoader?.call() ?? CategoryRepository().fetchCategories();
    final restaurantsFuture =
        widget.restaurantLoader?.call() ??
        RestaurantRepository().fetchRestaurants();
    final (categories, restaurants) = await (
      categoriesFuture,
      restaurantsFuture,
    ).wait;

    return _FoodHomeData(categories: categories, restaurants: restaurants);
  }

  void _retry() {
    setState(() => _homeFuture = _loadHome());
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
    final palette = context.serviceColors;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const ZivoLogo(height: 34),
        actions: [
          IconButton(
            onPressed: null,
            icon: Icon(Icons.notifications_none, color: palette.accent),
          ),
          const SizedBox(width: TwSpacing.x2),
        ],
      ),
      body: FutureBuilder<_FoodHomeData>(
        future: _homeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _FoodHomeError(onRetry: _retry);
          }
          return _buildHomeContent(snapshot.requireData);
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: CartController.instance,
        builder: (context, _) {
          final count = CartController.instance.itemCount;
          if (count == 0) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => context.push(AppRoutes.foodCart),
            icon: Badge(
              label: Text('$count'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: const Text('View cart'),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent(_FoodHomeData data) {
    final palette = context.serviceColors;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(TwSpacing.x5),
            child: Column(
              children: [
                OutlinedCard(
                  backgroundColor: palette.card,
                  borderColor: palette.border,
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
                            hintText: 'Search restaurants...',
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
                const SizedBox(height: TwSpacing.x5),
                SectionHeader(
                  title: 'Categories',
                  actionLabel: 'See All',
                  onPressed: _openCategories,
                ),
                const SizedBox(height: TwSpacing.x4),
                CategoriesSection(
                  categories: data.categories,
                  selectedCategoryId: _selectedCategoryId,
                  onCategorySelected: _selectCategory,
                ),
                const SizedBox(height: TwSpacing.x8),
                SectionHeader(
                  title: 'Trending Now',
                  actionLabel: 'View All',
                  onPressed: _openExplore,
                ),
              ],
            ),
          ),
        ),
        _filteredRestaurants == null
            ? _buildRestaurantResults(data.restaurants)
            : _buildFilteredRestaurantResults(_filteredRestaurants!),
        const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x5)),
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
      padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
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
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
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
      child: RestaurantCard(
        restaurant: restaurant,
        onPressed: () => _openRestaurant(restaurant),
      ),
    );
  }
}

class _FoodHomeData {
  const _FoodHomeData({required this.categories, required this.restaurants});

  final List<Category> categories;
  final List<Restaurant> restaurants;
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
