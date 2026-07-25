import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../models/category.dart';
import 'category_card.dart';
import 'section_header.dart';

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    required this.categoriesFuture,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onSeeAllPressed,
  });

  final Future<List<Category>> categoriesFuture;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onSeeAllPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Categories',
          actionLabel: '',
          onPressed: onSeeAllPressed,
        ),
        const SizedBox(height: TwSpacing.x4),
        SizedBox(
          height: 116,
          child: FutureBuilder<List<Category>>(
            future: categoriesFuture,
            builder: _buildCategories,
          ),
        ),
      ],
    );
  }

  Widget _buildCategories(
    BuildContext context,
    AsyncSnapshot<List<Category>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      debugPrint('Failed to load categories: ${snapshot.error}');
      return const Center(
        child: Text('Unable to load categories'),
      );
    }

    final categories = snapshot.data ?? const <Category>[];
    if (categories.isEmpty) {
      return const Center(
        child: Text('No categories found'),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: _buildSeparator,
      itemBuilder: (context, index) {
        final category = categories[index];

        return CategoryCard(
          category: category,
          isSelected: category.id == selectedCategoryId,
          onPressed: () => onCategorySelected(category.id),
        );
      },
    );
  }

  Widget _buildSeparator(BuildContext context, int index) {
    return const SizedBox(width: TwSpacing.x4);
  }
}
