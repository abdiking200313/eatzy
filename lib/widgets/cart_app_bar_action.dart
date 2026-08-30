import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The standard cart entry point for every service vertical (food, grocery,
/// pharmacy): a top-right `AppBar` action with a filled, service-accent-soft
/// background chip and a solid cart icon, plus an accent-colored count
/// badge, so the cart reads as clearly and consistently on one screen as on
/// any other — never a bare outline [IconButton] with the default
/// [Badge] styling.
class CartAppBarAction extends StatelessWidget {
  const CartAppBarAction({
    super.key,
    required this.itemCount,
    required this.onPressed,
    required this.tooltip,
    this.icon = Icons.shopping_cart_rounded,
  });

  /// Number of items currently in the cart. The count badge is hidden
  /// (but the chip itself always stays visible) when this is zero.
  final int itemCount;

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  static const double _dimension = 44;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x2),
      child: Badge(
        isLabelVisible: itemCount > 0,
        label: Text('$itemCount'),
        backgroundColor: palette.accent,
        textColor: palette.onAccent,
        child: SizedBox.square(
          dimension: _dimension,
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: palette.soft,
              foregroundColor: palette.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TwRadius.lg),
              ),
            ),
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
