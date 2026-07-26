import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../models/category.dart';
import 'category_card.dart';

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    required this.categoriesFuture,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final Future<List<Category>> categoriesFuture;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: FutureBuilder<List<Category>>(
        future: categoriesFuture,
        builder: _buildCategories,
      ),
    );
  }

  Widget _buildCategories(
    BuildContext context,
    AsyncSnapshot<List<Category>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      debugPrint('Failed to load categories: ${snapshot.error}');
      return _CategoryLoadError(error: snapshot.error!);
    }

    final categories = snapshot.data ?? const <Category>[];
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

class _CategoryLoadError extends StatelessWidget {
  const _CategoryLoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: TwColors.error),
            const SizedBox(height: TwSpacing.x1),
            Text(
              'Unable to load categories',
              textAlign: TextAlign.center,
              style: TwText.fontBoldSm().copyWith(color: TwColors.error),
            ),
            const SizedBox(height: TwSpacing.x1),
            Text(
              error.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TwText.textXs().copyWith(color: TwColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
