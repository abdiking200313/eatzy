import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/store_row_card.dart';
import '../data/restaurant_repository.dart';
import '../models/restaurant.dart';

/// The restaurant list — mirrors `GroceryScreen`'s "heading + blurb +
/// search field + flat list" shape rather than a photo-forward feed, so the
/// three verticals' store-list screens read as one consistent pattern.
class FoodExploreScreen extends StatefulWidget {
  const FoodExploreScreen({
    super.key,
    this.repository,
    this.restaurants,
    this.categoryId,
    this.categoryName,
  });

  final RestaurantRepository? repository;
  final Future<List<Restaurant>>? restaurants;

  /// When set (from tapping a category card in [FoodCategoriesScreen]),
  /// narrows the list to restaurants with at least one menu item in this
  /// `item_categories.id`, and [categoryName] is shown as the page title.
  final String? categoryId;
  final String? categoryName;

  @override
  State<FoodExploreScreen> createState() => _FoodExploreScreenState();
}

class _FoodExploreScreenState extends State<FoodExploreScreen> {
  late final Future<List<Restaurant>> _restaurants =
      widget.restaurants ??
      (widget.repository ?? RestaurantRepository()).fetchRestaurants(
        categoryId: widget.categoryId,
      );

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() => setState(() {});

  void _clearSearch() => _searchController.clear();

  List<Restaurant> _visibleRestaurants(List<Restaurant> restaurants) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return restaurants;
    }
    return restaurants
        .where((restaurant) => restaurant.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.categoryName ?? 'Explore restaurants',
      showBackButton: true,
      body: FutureBuilder<List<Restaurant>>(
        future: _restaurants,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _FoodExploreMessage(
              icon: Icons.cloud_off_outlined,
              text: 'Restaurants could not be loaded.',
            );
          }

          final allRestaurants = snapshot.data ?? const <Restaurant>[];
          if (allRestaurants.isEmpty) {
            return _FoodExploreMessage(
              icon: Icons.restaurant_outlined,
              text: widget.categoryId == null
                  ? 'No restaurants are available yet.'
                  : 'No restaurants found in this category.',
            );
          }

          final restaurants = _visibleRestaurants(allRestaurants);
          final showEmptyRow = restaurants.isEmpty;
          final itemCount = 1 + (showEmptyRow ? 1 : restaurants.length);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.screenX,
              TwSpacing.x2,
              TwSpacing.screenX,
              TwSpacing.x6,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: TwSpacing.x5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Restaurants near you', style: TwText.sectionTitle),
                      const SizedBox(height: TwSpacing.x2),
                      Text(
                        'Pick a restaurant to browse its menu.',
                        style: TwText.textSm,
                      ),
                      const SizedBox(height: TwSpacing.x5),
                      _searchField(),
                    ],
                  ),
                );
              }

              if (showEmptyRow) {
                return _NoSearchMatches(
                  searchQuery: _searchController.text.trim(),
                );
              }

              final restaurant = restaurants[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: TwSpacing.x3),
                child: StoreRowCard(
                  imageUrl: restaurant.logoUrl,
                  fallbackIcon: Icons.restaurant_rounded,
                  name: restaurant.name,
                  subtitleLines: [
                    if (restaurant.description.trim().isNotEmpty)
                      restaurant.description,
                  ],
                  onTap: () =>
                      context.push(AppRoutes.restaurantDetails(restaurant.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _searchField() {
    return AppSearchBar(
      controller: _searchController,
      hintText: 'Search restaurants...',
      onClear: _clearSearch,
    );
  }
}

class _NoSearchMatches extends StatelessWidget {
  const _NoSearchMatches({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TwSpacing.x8),
      child: Center(
        child: Text(
          'No restaurants match "$searchQuery".',
          textAlign: TextAlign.center,
          style: TwText.textSm,
        ),
      ),
    );
  }
}

class _FoodExploreMessage extends StatelessWidget {
  const _FoodExploreMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.serviceColors.accent, size: 48),
            const SizedBox(height: TwSpacing.x3),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
