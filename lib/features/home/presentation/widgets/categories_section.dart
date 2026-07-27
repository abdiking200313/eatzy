import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../models/category.dart';
import 'category_card.dart';

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 132, child: _buildCategories(context));
  }

  Widget _buildCategories(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories found'));
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
