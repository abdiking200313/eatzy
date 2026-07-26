import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';
import '../data/category_repository.dart';
import '../models/category.dart';
import 'widgets/category_card.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    this.showBackButton = true,
    this.categoryRepository,
    this.categoriesFuture,
  }) : assert(
         categoryRepository == null || categoriesFuture == null,
         'Provide either categoryRepository or categoriesFuture, not both.',
       );

  final bool showBackButton;
  final CategoryRepository? categoryRepository;
  final Future<List<Category>>? categoriesFuture;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  @override
  void didUpdateWidget(CategoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.categoriesFuture != widget.categoriesFuture ||
        oldWidget.categoryRepository != widget.categoryRepository) {
      _categoriesFuture = _loadCategories();
    }
  }

  Future<List<Category>> _loadCategories() {
    return widget.categoriesFuture ??
        (widget.categoryRepository ?? CategoryRepository()).fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Categories',
      showBackButton: widget.showBackButton,
      body: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
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
      return const Center(child: Text('Unable to load categories'));
    }

    final categories = snapshot.data ?? const <Category>[];
    if (categories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(TwSpacing.x5),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: TwSpacing.x5,
        mainAxisSpacing: TwSpacing.x5,
        childAspectRatio: 1.1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return CategoryCard(category: categories[index]);
      },
    );
  }
}
