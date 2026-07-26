import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/zivo_logo.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/models/category.dart';
import '../../categories/presentation/widgets/categories_section.dart';
import '../data/sample_restaurants.dart';
import 'widgets/restaurant_card.dart';
import 'widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                _buildRestaurant,
                childCount: sampleRestaurants.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x5)),
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
