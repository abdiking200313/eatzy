import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/activity/presentation/activity_controller.dart';
import '../platform/cache/query_cache.dart';
import '../platform/error_reporting/error_reporter.dart';
import '../platform/session/session_reset_registry.dart';
import '../services/food/presentation/cart_controller.dart';
import '../services/grocery/data/grocery_repository.dart';
import '../services/grocery/models/grocery_models.dart';
import '../services/grocery/presentation/grocery_controller.dart';
import '../services/pharmacy/data/pharmacy_repository.dart';
import '../services/pharmacy/models/pharmacy_cart_item.dart';
import '../services/pharmacy/presentation/pharmacy_controller.dart';
import '../services/shared/data/cart_storage.dart';

/// The app's composition root: a single plain Dart object holding every
/// shared dependency a screen/controller needs, instead of each call site
/// reaching for `Supabase.instance.client` or a process-wide `.instance`
/// singleton directly.
///
/// This is deliberately *not* a new state-management framework (no
/// Riverpod/get_it/provider) — see `AGENTS.md`'s "do not introduce a new
/// state management framework" rule. It's a plain constructor-injected
/// bundle, exposed to the widget tree via [AppScope] (`app_scope.dart`).
///
/// The eagerly-built fields below — the Supabase client, [QueryCache],
/// [ErrorReporter], [SessionResetRegistry], [CartController], and
/// [ActivityController] — are also reachable through their own
/// `.instance` singletons, for any call site that reads them that way
/// instead of through [AppScope].
///
/// [groceryController]/[pharmacyController] are built lazily on first
/// access and then cached, unlike the fields above — a user who never
/// opens grocery or pharmacy must not trigger their catalog queries just
/// because [AppServices] exists. Every call site reads them off
/// [AppScope].
class AppServices {
  AppServices({
    required this.supabaseClient,
    required this.queryCache,
    required this.errorReporter,
    required this.sessionResetRegistry,
    required this.cartController,
    required this.activityController,
  });

  /// Builds the production [AppServices], wired to the existing process-wide
  /// singletons. Called exactly once, from `runStartupSequence` after
  /// `Supabase.initialize` has completed successfully — every field read
  /// here must already be safe to use at that point.
  factory AppServices.fromSingletons() => AppServices(
    supabaseClient: Supabase.instance.client,
    queryCache: QueryCache.instance,
    errorReporter: ErrorReporting.instance,
    sessionResetRegistry: SessionResetRegistry.instance,
    cartController: CartController.instance,
    activityController: ActivityController.instance,
  );

  final SupabaseClient supabaseClient;
  final QueryCache queryCache;
  final ErrorReporter errorReporter;
  final SessionResetRegistry sessionResetRegistry;
  final CartController cartController;
  final ActivityController activityController;

  /// One [GroceryController] per [GroceryStoreType] (Grocery, Fresh Meat,
  /// and Electronics each keep their own cart/catalog — see
  /// `GroceryController.storeType`), built lazily on first access and then
  /// cached here for the lifetime of this [AppServices], rather than as a
  /// process-wide singleton.
  final Map<GroceryStoreType, GroceryController> _groceryControllers = {};

  /// The grocery-engine controller for [type] — see [_groceryControllers].
  GroceryController groceryController(GroceryStoreType type) {
    return _groceryControllers.putIfAbsent(
      type,
      () => _buildGroceryController(type),
    );
  }

  // Deliberately does not call load() here: constructing a controller must
  // not issue catalog queries for users who never open that category.
  // Callers (GroceryScreen and friends) trigger load() on demand.
  GroceryController _buildGroceryController(GroceryStoreType type) {
    final catalog = SupabaseGroceryCatalogRepository(client: supabaseClient);
    final controller = GroceryController(
      repository: catalog,
      catalogRepository: catalog,
      orderRepository: SupabaseGroceryOrderRepository(client: supabaseClient),
      activityController: activityController,
      storage: SharedPreferencesCartStorage<GroceryCartLine>(
        // Grocery keeps its original key so existing saved carts survive.
        keyPrefix: type == GroceryStoreType.grocery
            ? 'zivo.cart.v1.grocery'
            : 'zivo.cart.v1.grocery.${type.dbValue}',
        toJson: (line) => line.toJson(),
        fromJson: GroceryCartLine.fromJson,
      ),
      storeType: type,
    );
    sessionResetRegistry.register((ownerId) {
      controller.resetSessionState();
      unawaited(controller.loadForOwner(ownerId));
    });
    return controller;
  }

  PharmacyController? _pharmacyController;

  /// The single pharmacy controller, built lazily on first access and then
  /// cached here, rather than as a process-wide singleton.
  PharmacyController get pharmacyController =>
      _pharmacyController ??= _buildPharmacyController();

  PharmacyController _buildPharmacyController() {
    final controller = PharmacyController(
      repository: SupabasePharmacyCatalogRepository(client: supabaseClient),
      orderRepository: SupabasePharmacyOrderRepository(client: supabaseClient),
      activityController: activityController,
      storage: SharedPreferencesCartStorage<PharmacyCartItem>(
        keyPrefix: 'zivo.cart.v1.pharmacy',
        toJson: (item) => item.toJson(),
        fromJson: PharmacyCartItem.fromJson,
      ),
    );
    sessionResetRegistry.register(
      (ownerId) => unawaited(controller.loadForOwner(ownerId)),
    );
    return controller;
  }
}
