import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../config/theme.dart';
import '../data/category_repository.dart';
import '../data/sample_restaurants.dart';
import '../models/category.dart';
import 'widgets/categories_section.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/home_search.dart';
import 'widgets/restaurant_card.dart';
import 'widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _categoryRepository = CategoryRepository();

  late final Future<List<Category>> _categoriesFuture;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryRepository.fetchCategories();
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  void _openCategories() => context.push(AppRoutes.categories);

  void _openExplore() => context.push(AppRoutes.explore);

  void _openCheckout() => context.push(AppRoutes.checkout);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.bg,
      appBar: const HomeAppBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                children: [
                  const HomeSearch(),
                  const SizedBox(height: TwSpacing.x5),
                  CategoriesSection(
                    categoriesFuture: _categoriesFuture,
                    selectedCategoryId: _selectedCategoryId,
                    onCategorySelected: _selectCategory,
                    onSeeAllPressed: _openCategories,
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
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                _buildRestaurant,
                childCount: sampleRestaurants.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: TwSpacing.x5),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurant(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x4),
      child: RestaurantCard(
        restaurant: sampleRestaurants[index],
        onOrderPressed: _openCheckout,
      ),
    );
  }
}
