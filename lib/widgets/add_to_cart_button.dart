import 'package:flutter/material.dart';

import '../config/theme.dart';

class AddToCartButton extends StatelessWidget {
  const AddToCartButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 44,
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.outlineVariant,
          disabledForegroundColor: TwColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwRadius.lg),
          ),
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
      ),
    );
  }
}
