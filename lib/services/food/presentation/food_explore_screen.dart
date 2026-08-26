import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';
import '../data/restaurant_repository.dart';
import '../models/restaurant.dart';
import 'widgets/restaurant_card.dart';

class FoodExploreScreen extends StatefulWidget {
  const FoodExploreScreen({super.key, this.repository, this.restaurants});

  final RestaurantRepository? repository;
  final Future<List<Restaurant>>? restaurants;

  @override
  State<FoodExploreScreen> createState() => _FoodExploreScreenState();
}

class _FoodExploreScreenState extends State<FoodExploreScreen> {
  late final Future<List<Restaurant>> _restaurants =
      widget.restaurants ??
      (widget.repository ?? RestaurantRepository()).fetchRestaurants();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Explore restaurants',
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
            return const _FoodExploreMessage(
              icon: Icons.restaurant_outlined,
              text: 'No restaurants are available yet.',
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
