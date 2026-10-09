import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_services.dart';
import '../../../app/service_module.dart';
import '../../../config/theme.dart';
import '../../../platform/cache/catalog_queries.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/product_details_view.dart';
import '../models/cart_item.dart';
import '../models/restaurant_menu.dart';
import 'cart_controller.dart';
import 'restaurant_screen.dart' show RestaurantMenuLoader;

/// A full-screen "more info" page for a single menu item, reached either by
/// tapping its card in `RestaurantScreen`'s menu or directly via
/// `AppRoutes.foodMenuItemDetails` (deep link / browser URL). A go_router
/// destination, like `RestaurantScreen` itself: it only takes
/// [restaurantId]/[itemId] and loads the item itself from the same
/// `CatalogQueries.restaurantMenu` cache `RestaurantScreen` reads from,
/// rather than taking the whole [MenuItem] object. A thin wrapper around the
/// shared [ProductDetailsView], the same as
/// `GroceryProductDetailsScreen`/`PharmacyProductDetailsScreen`.
class MenuItemDetailsScreen extends StatefulWidget {
  const MenuItemDetailsScreen({
    super.key,
    required this.restaurantId,
    required this.itemId,
    this.menuLoader,
    this.cartController,
  });

  final String restaurantId;
  final String itemId;

  /// Overridable for tests; bypasses [CatalogQueries.restaurantMenu] the
  /// same way `RestaurantScreen.menuLoader` does.
  final RestaurantMenuLoader? menuLoader;

  /// Overridable for tests; defaults to [AppServices.cartController].
  final CartController? cartController;

  @override
  State<MenuItemDetailsScreen> createState() => _MenuItemDetailsScreenState();
}

class _MenuItemDetailsScreenState extends State<MenuItemDetailsScreen> {
  late Stream<RestaurantMenu> _menu;

  /// The cached menu shown on the first frame, before [_menu] emits — see
  /// `RestaurantScreen._initialMenu`.
  RestaurantMenu? _initialMenu;

  /// Set in [didChangeDependencies] (never [initState]) — see
  /// `RestaurantScreen._services`'s doc comment.
  late AppServices _services;
  bool _dependenciesResolved = false;

  @override
  void initState() {
    super.initState();
    _startMenu();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesResolved) return;
    _dependenciesResolved = true;
    _services = AppScope.of(context);
  }

  void _startMenu() {
    final loader = widget.menuLoader;
    if (loader != null) {
      _initialMenu = null;
      _menu = Stream.fromFuture(loader(widget.restaurantId));
      return;
    }
    final query = CatalogQueries.restaurantMenu(widget.restaurantId);
    _initialMenu = query.peek();
    _menu = query.watch();
  }

  void _retry() => setState(_startMenu);

  MenuItem? _findItem(RestaurantMenu menu) {
    for (final category in menu.categories) {
      for (final item in category.items) {
        if (item.id == widget.itemId) return item;
      }
    }
    return null;
  }

  /// Mirrors `RestaurantScreen._addToCart` -- the cart-conflict dialog and
  /// snackbar are identical since this screen is reached the same way (a tap
  /// from that menu, or a deep link to the same item).
  Future<void> _addToCart(
    RestaurantMenu menu,
    MenuItem menuItem,
    int quantity,
  ) async {
    final controller = widget.cartController ?? _services.cartController;
    final cartItem = CartItem(
      menuItemId: menuItem.id,
      restaurantId: menu.restaurant.id,
      restaurantName: menu.restaurant.name,
      name: menuItem.name,
      unitPrice: menuItem.price,
      imageUrl: menuItem.imageUrl,
    );

    try {
      var result = await controller.addItem(cartItem, quantity: quantity);
      if (!mounted) {
        return;
      }

      if (result == CartAddResult.restaurantConflict) {
        final replaceCart = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Start a new cart?'),
            content: Text(
              'Your cart contains items from '
              '${controller.restaurantName ?? 'another restaurant'}. '
              'Starting a cart from ${menu.restaurant.name} will remove them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep cart'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Start new cart'),
              ),
            ],
          ),
        );

        if (replaceCart != true) {
          return;
        }
        result = await controller.addItem(
          cartItem,
          replaceRestaurantCart: true,
          quantity: quantity,
        );
      }

      if (!mounted) {
        return;
      }
      final itemLabel = quantity > 1
          ? '$quantity× ${menuItem.name}'
          : menuItem.name;
      final message = switch (result) {
        CartAddResult.quantityIncreased => '$itemLabel quantity increased',
        CartAddResult.replacedRestaurant => 'New cart started with $itemLabel',
        CartAddResult.maximumReached =>
          '${menuItem.name} is already at the maximum quantity',
        _ => '$itemLabel added to cart',
      };
      showCartSnackBar(context, message);
    } on Object {
      if (!mounted) {
        return;
      }
      showCartSnackBar(
        context,
        'The item was added, but the cart could not be saved.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RestaurantMenu>(
      stream: _menu,
      initialData: _initialMenu,
      builder: (context, snapshot) {
        final menu = snapshot.data;
        if (menu == null) {
          return AppScaffold(
            title: 'Item',
            showBackButton: true,
            body: snapshot.hasError
                ? _ErrorView(onRetry: _retry)
                : const Center(child: CircularProgressIndicator()),
          );
        }

        final item = _findItem(menu);
        if (item == null) {
          return const AppScaffold(
            title: 'Item',
            showBackButton: true,
            body: _ItemNotFoundView(),
          );
        }

        return ZivoServiceTheme(
          serviceId: ServiceId.food,
          child: ProductDetailsView(
            imageUrl: item.imageUrl,
            fallback: Icon(
              Icons.lunch_dining_rounded,
              size: 96,
              color: context.serviceColors.accent,
            ),
            name: item.name,
            priceLabel: AppMoney.formatCents(item.price),
            description: item.description,
            maxSteps: CartController.maximumQuantity,
            quantityLabel: (steps) => '$steps',
            onAddToCart: (quantity) =>
                unawaited(_addToCart(menu, item, quantity)),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This item could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TwSpacing.x4),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Shown for a cold deep link to an [MenuItemDetailsScreen.itemId] that no
/// longer resolves in the loaded menu (e.g. a stale/bad id, or the item was
/// removed from the menu) -- doesn't crash.
class _ItemNotFoundView extends StatelessWidget {
  const _ItemNotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(TwSpacing.x6),
        child: Text(
          'This item is no longer available.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
