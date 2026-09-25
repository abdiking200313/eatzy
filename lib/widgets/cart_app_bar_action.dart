import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// The cart badge shortcut shared by grocery's and pharmacy's store-list and
/// store-scoped catalog screens, each of which shows one of these in its app
/// bar. Isolated in its own [AnimatedBuilder] so a cart mutation only
/// rebuilds this small badge, not whatever (potentially long) list sits
/// underneath it in the app bar's screen. Takes a bare [listenable] plus an
/// [itemCount] reader rather than a controller type, so it doesn't need to
/// depend on either `GroceryController` or `PharmacyController`.
class CartBadgeAction extends StatelessWidget {
  const CartBadgeAction({
    super.key,
    required this.listenable,
    required this.itemCount,
    required this.icon,
    required this.tooltip,
    required this.route,
  });

  /// The cart-owning controller to rebuild on, e.g.
  /// `GroceryController.instance`.
  final Listenable listenable;

  /// Reads the current item count off [listenable] at build time.
  final int Function() itemCount;

  final IconData icon;

  /// Built with the current item count, e.g. `(n) => 'Grocery cart ($n)'`.
  final String Function(int itemCount) tooltip;

  /// The go_router route pushed on tap, e.g. `AppRoutes.groceryCart`.
  final String route;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final count = itemCount();
        return CartAppBarAction(
          key: key,
          itemCount: count,
          tooltip: tooltip(count),
          onPressed: () => context.push(route),
          icon: icon,
        );
      },
    );
  }
}
