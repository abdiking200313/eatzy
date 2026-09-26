import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'app_cards.dart';

/// A pill-shaped search field scoped to a single store's catalog. Shared by
/// `GroceryStoreScreen` and `PharmacyCatalogScreen`, which differ only in
/// hint text and whether they react to keystrokes live (pharmacy debounces
/// a server search via [onChanged]; grocery filters its already-loaded
/// product list from the [controller] alone).
class StoreSearchField extends StatelessWidget {
  const StoreSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onClear,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onClear;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedCard(
        backgroundColor: TwColors.card,
        borderColor: TwColors.border,
        borderRadius: TwRadius.input,
        padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x4),
        child: Row(
          children: [
            const Icon(Icons.search, color: TwColors.textMuted),
            const SizedBox(width: TwSpacing.x3),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: const TextStyle(color: TwColors.textMuted),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.clear,
                    size: 20,
                    color: TwColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
