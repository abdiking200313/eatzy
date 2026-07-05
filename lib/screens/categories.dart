import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<String> _categories = [
    'Food',
    'Pharmacy',
    'Grocery',
    'Cleaner',
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Categories',
      showBackButton: true,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.4,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) => OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Center(
              child: Text(
                _categories[index],
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
