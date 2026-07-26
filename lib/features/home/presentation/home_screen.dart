import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/zivo_logo.dart';
import '../data/category_repository.dart';
import '../data/restaurant_repository.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import 'widgets/categories_section.dart';
import 'widgets/restaurant_card.dart';
import 'widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _categoryRepository = CategoryRepository();
  final _restaurantRepository = RestaurantRepository();

  late final Future<List<Category>> _categoriesFuture;
  late Future<List<Restaurant>> _restaurantsFuture;
  String? _selectedCategoryId;
  //String? _selectedRestaurantId;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryRepository.fetchCategories();
    _restaurantsFuture = _restaurantRepository.fetchRestaurants();
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  void _openCategories() => context.push(AppRoutes.categories);

  void _openExplore() => context.push(AppRoutes.explore);

  void _openRestaurant(Restaurant restaurant) =>
      context.push(AppRoutes.restaurantDetails(restaurant.id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.bg,
      appBar: AppBar(
        backgroundColor: TwColors.bg,
        elevation: 0,
        title: const ZivoLogo(height: 34),
        actions: [
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.notifications_none, color: TwColors.primary),
          ),
          const SizedBox(width: TwSpacing.x2),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                children: [
                  const OutlinedCard(
                    backgroundColor: Colors.white,
                    borderRadius: 50,
                    child: Row(
                      children: [
                        Icon(Icons.search, color: TwColors.borderStrong),
                        SizedBox(width: TwSpacing.x4),
                        Expanded(
                          child: Text(
                            'Search restaurants...',
                            style: TextStyle(color: TwColors.borderStrong),
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
                    categoriesFuture: _categoriesFuture,
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
          FutureBuilder<List<Restaurant>>(
            future: _restaurantsFuture,
            builder: _buildRestaurantResults,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x5)),
        ],
      ),
    );
  }

  Widget _buildRestaurantResults(
    BuildContext context,
    AsyncSnapshot<List<Restaurant>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(TwSpacing.x8),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x5),
          child: OutlinedCard(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined, color: TwColors.primary),
                const SizedBox(height: TwSpacing.x2),
                const Text('Restaurants could not be loaded.'),
              ],
            ),
          ),
        ),
      );
    }

    final restaurants = snapshot.data ?? const <Restaurant>[];
    if (restaurants.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(TwSpacing.x8),
          child: Center(child: Text('No restaurants found in this category.')),
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
