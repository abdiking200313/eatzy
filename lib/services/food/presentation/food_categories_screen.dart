import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../features/home/data/category_repository.dart';
import '../../../features/home/models/category.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';

class FoodCategoriesScreen extends StatefulWidget {
  const FoodCategoriesScreen({super.key, this.repository, this.categories});

  final CategoryRepository? repository;

  /// Test seam mirroring [FoodExploreScreen]'s `restaurants` parameter —
  /// lets tests inject data directly without a live Supabase client.
  final Future<List<Category>>? categories;

  @override
  State<FoodCategoriesScreen> createState() => _FoodCategoriesScreenState();
}

class _FoodCategoriesScreenState extends State<FoodCategoriesScreen> {
  late final Future<List<Category>> _categories =
      widget.categories ??
      (widget.repository ?? CategoryRepository()).fetchCategories();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Food categories',
      showBackButton: true,
      body: FutureBuilder<List<Category>>(
        future: _categories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _Message(
              icon: Icons.cloud_off_outlined,
              text: 'Food categories could not be loaded.',
            );
          }

          final categories = snapshot.data ?? const <Category>[];
          if (categories.isEmpty) {
            return const _Message(
              icon: Icons.category_outlined,
              text: 'No food categories are available yet.',
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(TwSpacing.x5),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: TwSpacing.x4,
              mainAxisSpacing: TwSpacing.x4,
              // Tall enough for the 48px icon chip plus a two-line label at
              // a 1.4x text scale on a 320px-wide screen without overflow.
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              // White card only — the service accent is confined to the
              // 48px ServiceIconChip rather than tinting the card itself.
              return OutlinedCard(
                onTap: () => _openCategory(context, category),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ServiceIconChip(icon: Icons.restaurant_menu),
                    const SizedBox(height: TwSpacing.rhythmTight),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.fontBoldSm,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openCategory(BuildContext context, Category category) {
    context.push(
      Uri(
        path: AppRoutes.foodExplore,
        queryParameters: {
          'categoryId': category.id,
          'categoryName': category.name,
        },
      ).toString(),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

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
