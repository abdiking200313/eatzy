import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  static const List<_Dish> _dishes = [
    _Dish(name: 'Smoky Party Jollof', price: 'NGN 2,500'),
    _Dish(name: 'Grilled Chicken Bowl', price: 'NGN 3,200'),
    _Dish(name: 'Pepper Soup Pot', price: 'NGN 2,900'),
    _Dish(name: 'Suya Rice Special', price: 'NGN 3,100'),
    _Dish(name: 'Amala Feast', price: 'NGN 2,700'),
    _Dish(name: 'Burger & Fries Box', price: 'NGN 3,400'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Explore',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Explore Popular Dishes'),
            const SizedBox(height: AppSpacing.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 0.8,
              ),
              itemCount: _dishes.length,
              itemBuilder: (context, index) => _DishCard(dish: _dishes[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish});

  final _Dish dish;

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
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name, style: AppTextStyles.cardTitleSm()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dish.price,
                  style: AppTextStyles.cardTitle().copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dish {
  const _Dish({required this.name, required this.price});

  final String name;
  final String price;
}
