import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../features/home/data/category_repository.dart';
import '../../../features/home/models/category.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';

class FoodCategoriesScreen extends StatefulWidget {
  const FoodCategoriesScreen({super.key, this.repository});

  final CategoryRepository? repository;

  @override
  State<FoodCategoriesScreen> createState() => _FoodCategoriesScreenState();
}

class _FoodCategoriesScreenState extends State<FoodCategoriesScreen> {
  late final Future<List<Category>> _categories =
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
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              final palette = context.serviceColors;
              return OutlinedCard(
                backgroundColor: palette.card,
                borderColor: palette.border,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, color: palette.accent),
                    const SizedBox(height: TwSpacing.x2),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      style: TwText.fontBoldSm(),
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
