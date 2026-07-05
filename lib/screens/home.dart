import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<_Category> _categories = [
    _Category(label: 'Burgers', icon: Icons.lunch_dining),
    _Category(label: 'Pizza', icon: Icons.local_pizza),
    _Category(label: 'Sushi', icon: Icons.set_meal),
    _Category(label: 'African', icon: Icons.rice_bowl),
    _Category(label: 'Desserts', icon: Icons.cake),
  ];

  static const List<_Restaurant> _restaurants = [
    _Restaurant(
      name: 'Premium Restaurant 1',
      rating: '4.5',
      reviews: '50+ reviews',
      price: 'NGN 1,500',
      distance: '2 km away',
    ),
    _Restaurant(
      name: 'Premium Restaurant 2',
      rating: '4.6',
      reviews: '50+ reviews',
      price: 'NGN 1,700',
      distance: '3 km away',
    ),
    _Restaurant(
      name: 'Premium Restaurant 3',
      rating: '4.7',
      reviews: '50+ reviews',
      price: 'NGN 1,900',
      distance: '4 km away',
    ),
    _Restaurant(
      name: 'Premium Restaurant 4',
      rating: '4.8',
      reviews: '50+ reviews',
      price: 'NGN 2,100',
      distance: '5 km away',
    ),
    _Restaurant(
      name: 'Premium Restaurant 5',
      rating: '4.9',
      reviews: '50+ reviews',
      price: 'NGN 2,300',
      distance: '6 km away',
    ),
    _Restaurant(
      name: 'Premium Restaurant 6',
      rating: '5.0',
      reviews: '50+ reviews',
      price: 'NGN 2,500',
      distance: '7 km away',
    ),
  ];

  int _selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'ChowFlow',
          style: AppTextStyles.h3().copyWith(color: AppColors.primary),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.base),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  OutlinedCard(
                    backgroundColor: Colors.white,
                    borderRadius: 50,
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: AppColors.outlineVariant),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Search restaurants...',
                            style: TextStyle(color: AppColors.outlineVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(
                    title: 'Categories',
                    actionLabel: 'See All',
                    onPressed: () => context.push(AppRoutes.categories),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) => _CategoryChip(
                        category: _categories[index],
                        isSelected: _selectedCategory == index,
                        onTap: () => setState(() => _selectedCategory = index),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(
                    title: 'Trending Now',
                    actionLabel: 'View All',
                    onPressed: () => context.push(AppRoutes.explore),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RestaurantCard(restaurant: _restaurants[index]),
                ),
                childCount: _restaurants.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.sectionTitle()),
        TextButton(
          onPressed: onPressed,
          child: Text(actionLabel, style: AppTextStyles.actionLink()),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _Category category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected ? AppColors.fireSunGradient : null,
              color: isSelected ? null : AppColors.surfaceContainer,
            ),
            child: Icon(
              category.icon,
              size: 34,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Text(
          category.label,
          style: AppTextStyles.labelSm().copyWith(
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant});

  final _Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 16,
      borderColor: Colors.transparent,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant.name, style: AppTextStyles.sectionTitle()),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${restaurant.rating} · ${restaurant.reviews}',
                      style: AppTextStyles.labelSm().copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      restaurant.price,
                      style: AppTextStyles.cardTitleSm().copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        restaurant.distance,
                        style: AppTextStyles.labelSm().copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    PrimaryButton(
                      label: 'Order',
                      onPressed: () => context.push(AppRoutes.checkout),
                      fullWidth: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  const _Category({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _Restaurant {
  const _Restaurant({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.distance,
  });

  final String name;
  final String rating;
  final String reviews;
  final String price;
  final String distance;
}
