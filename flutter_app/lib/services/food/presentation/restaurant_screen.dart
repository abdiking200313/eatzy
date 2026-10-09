import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_services.dart';
import '../../../platform/cache/catalog_queries.dart';
import '../../../widgets/app_misc.dart';
import '../data/food_repository.dart';
import '../models/cart_item.dart';
import '../models/food_models.dart';
import '../models/restaurant_menu.dart';
import 'cart_controller.dart';
import 'widgets/category_header_delegate.dart';
import 'widgets/restaurant_cart_fab.dart';
import 'widgets/restaurant_menu_view.dart';
import 'widgets/restaurant_status_views.dart';

typedef RestaurantMenuLoader =
    Future<RestaurantMenu> Function(String restaurantId);

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({
    super.key,
    required this.restaurantId,
    this.menuLoader,
    this.cartController,
    this.locationRepository,
  });

  final String restaurantId;
  final RestaurantMenuLoader? menuLoader;
  final CartController? cartController;
  final RestaurantLocationRepository? locationRepository;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _sectionKeys = <String, GlobalKey>{};
  final _scrollController = ScrollController();

  late Stream<RestaurantMenu> _menu;

  /// The cached menu shown on the first frame, before [_menu] emits.
  RestaurantMenu? _initialMenu;
  late Future<List<RestaurantLocation>> _locationsFuture;
  String? _selectedCategoryId;

  /// Set in [didChangeDependencies] (never [initState] — `AppScope.of`
  /// depends on an ancestor `InheritedWidget` that isn't safely readable
  /// yet at that point). Every call site below reads
  /// `Supabase.instance.client`/`CartController.instance` through this
  /// instead of directly.
  late AppServices _services;
  bool _locationsLoadStarted = false;

  // The pinned category chip bar sits right below the collapsed app bar
  // (`kToolbarHeight`, since `StoreHeroAppBar` is `pinned: true`) once
  // scrolled past its `expandedHeight` hero. A section counts as "current"
  // once its heading has scrolled up to (or past) that line, matching what
  // a user reading top-to-bottom would call the category they're looking
  // at — not the strict top-of-viewport, which would flip a beat too late.
  double get _sectionThreshold =>
      MediaQuery.of(context).padding.top +
      kToolbarHeight +
      kCategoryHeaderExtent;

  @override
  void initState() {
    super.initState();
    _startMenu();
    _scrollController.addListener(_syncSelectedCategoryFromScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = AppScope.of(context);
    if (!_locationsLoadStarted) {
      _locationsLoadStarted = true;
      _locationsFuture = _loadLocations();
    }
  }

  /// An injected [RestaurantScreen.menuLoader] (tests) bypasses the cache;
  /// the real app shows the last-known menu instantly and refreshes it in
  /// the background via [CatalogQueries.restaurantMenu].
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

  void _syncSelectedCategoryFromScroll() {
    if (_sectionKeys.isEmpty) {
      return;
    }
    final threshold = _sectionThreshold;
    String? currentId;
    for (final entry in _sectionKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }
      final top = renderObject.localToGlobal(Offset.zero).dy;
      if (top <= threshold) {
        currentId = entry.key;
      } else {
        break;
      }
    }
    if (currentId != null && currentId != _selectedCategoryId) {
      setState(() => _selectedCategoryId = currentId);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncSelectedCategoryFromScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<RestaurantLocation>> _loadLocations() async {
    try {
      final repository =
          widget.locationRepository ??
          SupabaseRestaurantLocationRepository(
            client: _services.supabaseClient,
          );
      return await repository.fetchLocations(widget.restaurantId);
    } on Object {
      return const [];
    }
  }

  @override
  void didUpdateWidget(covariant RestaurantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantId != widget.restaurantId ||
        oldWidget.menuLoader != widget.menuLoader ||
        oldWidget.locationRepository != widget.locationRepository) {
      _sectionKeys.clear();
      _selectedCategoryId = null;
      _startMenu();
      _locationsFuture = _loadLocations();
    }
  }

  void _retry() {
    setState(() {
      _startMenu();
      _locationsFuture = _loadLocations();
    });
  }

  void _selectCategory(MenuCategory category) {
    setState(() => _selectedCategoryId = category.id);

    final sectionContext = _sectionKeys[category.id]?.currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

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
    final cartController = widget.cartController ?? _services.cartController;
    return Scaffold(
      body: StreamBuilder<RestaurantMenu>(
        stream: _menu,
        initialData: _initialMenu,
        builder: (context, snapshot) {
          // A cached menu wins over both the loading state and a failed
          // background refresh; errors only show when nothing was cached.
          final menu = snapshot.data;
          if (menu == null) {
            return snapshot.hasError
                ? RestaurantErrorView(onRetry: _retry)
                : const RestaurantLoadingView();
          }

          return RestaurantMenuView(
            menu: menu,
            locationsFuture: _locationsFuture,
            selectedCategoryId: _selectedCategoryId,
            scrollController: _scrollController,
            sectionKeyFor: (categoryId) =>
                _sectionKeys.putIfAbsent(categoryId, GlobalKey.new),
            onCategorySelected: _selectCategory,
            onAddToCart: (item, quantity) => _addToCart(menu, item, quantity),
          );
        },
      ),
      floatingActionButton: RestaurantCartFab(
        controller: cartController,
        onViewCart: () => context.push(AppRoutes.foodCart),
      ),
    );
  }
}
