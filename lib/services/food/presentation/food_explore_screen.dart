import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../features/home/data/restaurant_repository.dart';
import '../../../features/home/models/restaurant.dart';
import '../../../features/home/presentation/widgets/restaurant_card.dart';
import '../../../widgets/app_scaffold.dart';

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

          final restaurants = snapshot.data ?? const <Restaurant>[];
          if (restaurants.isEmpty) {
            return _FoodExploreMessage(
              icon: Icons.restaurant_outlined,
              text: widget.categoryId == null
                  ? 'No restaurants are available yet.'
                  : 'No restaurants found in this category.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(TwSpacing.x5),
            itemCount: restaurants.length,
            separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x4),
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              return RestaurantCard(
                restaurant: restaurant,
                onPressed: () =>
                    context.push(AppRoutes.restaurantDetails(restaurant.id)),
              );
            },
          );
        },
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
