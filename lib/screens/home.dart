import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/zivo_logo.dart';

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
      backgroundColor: TwColors.bg,
      appBar: AppBar(
        backgroundColor: TwColors.bg,
        elevation: 0,
        title: const ZivoLogo(height: 34),
        actions: [
          IconButton(
            onPressed: () {},
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
                  OutlinedCard(
                    backgroundColor: Colors.white,
                    borderRadius: 50,
                    child: const Row(
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
                  _SectionHeader(
                    title: 'Categories',
                    actionLabel: 'See All',
                    onPressed: () => context.push(AppRoutes.categories),
                  ),
                  const SizedBox(height: TwSpacing.x4),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: TwSpacing.x4),
                      itemBuilder: (context, index) => _CategoryChip(
                        category: _categories[index],
                        isSelected: _selectedCategory == index,
                        onTap: () => setState(() => _selectedCategory = index),
                      ),
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x8),
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
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: TwSpacing.x4),
                  child: _RestaurantCard(restaurant: _restaurants[index]),
                ),
                childCount: _restaurants.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: TwSpacing.x5)),
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
        Text(title, style: TwText.textXl()),
        TextButton(
          onPressed: onPressed,
          child: Text(actionLabel, style: TwText.link()),
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
              gradient: isSelected ? TwColors.primaryGradient : null,
              color: isSelected ? null : TwColors.cardMuted,
            ),
            child: Icon(
              category.icon,
              size: 34,
              color: isSelected ? Colors.white : TwColors.primary,
            ),
          ),
        ),
        const SizedBox(height: TwSpacing.x2),
        Text(
          category.label,
          style: TwText.textXs().copyWith(
            color: isSelected ? TwColors.primary : TwColors.textMuted,
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
              color: TwColors.primaryAccent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TwSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant.name, style: TwText.textXl()),
                const SizedBox(height: TwSpacing.x3),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: TwColors.blue400,
                      size: 18,
                    ),
                    const SizedBox(width: TwSpacing.x1),
                    Text(
                      '${restaurant.rating} · ${restaurant.reviews}',
                      style: TwText.textXs().copyWith(
                        color: TwColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      restaurant.price,
                      style: TwText.fontBoldSm().copyWith(
                        color: TwColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TwSpacing.x4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: TwColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: TwSpacing.x1),
                    Expanded(
                      child: Text(
                        restaurant.distance,
                        style: TwText.textXs().copyWith(
                          color: TwColors.textMuted,
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
