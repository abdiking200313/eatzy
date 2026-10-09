import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:chowflow/services/shared/data/cart_storage.dart';
import 'package:chowflow/services/shared/data/service_pricing_repository.dart';

import 'fake_service_pricing_repository.dart';
import 'memory_cart_storage.dart';

/// Builds a [GroceryController] backed by [SeededGroceryRepository] (or a
/// caller-supplied fake/[repository]) and a fresh in-memory
/// [ActivityController] + [MemoryCartStorage] — shared setup for grocery
/// widget/controller tests. Pass [orderRepository], [activityController],
/// [storage] or [now] to override any one of the defaults, e.g. to share an
/// [ActivityController] across controllers or to inspect its recorded
/// items, or to reuse the same [storage] across a "simulated app reload".
///
/// This does not call [GroceryController.load] — callers keep control over
/// when the catalog is fetched and can inspect the loading state in
/// between. Use [buildLoadedGroceryController] for the common case where a
/// test just wants an already-loaded controller.
GroceryController buildGroceryController({
  GroceryRepository repository = const SeededGroceryRepository(),
  GroceryOrderRepository? orderRepository,
  ActivityController? activityController,
  CartStorage<GroceryCartLine>? storage,
  ServicePricingRepository? pricingRepository,
  DateTime Function()? now,
}) {
  return GroceryController(
    repository: repository,
    orderRepository: orderRepository,
    activityController: activityController ?? ActivityController(),
    storage: storage ?? MemoryCartStorage<GroceryCartLine>(),
    // Pre-seeded with a standard default so a test doesn't have to
    // inject pricing itself unless it cares; pass an explicit
    // [pricingRepository] to test different pricing (or
    // `FakeServicePricingRepository.unconfigured()` to test the "pricing
    // never loaded" fallback).
    pricingRepository:
        pricingRepository ?? FakeServicePricingRepository.grocery(),
    now: now,
  );
}

/// As [buildGroceryController], but also awaits [GroceryController.load] so
/// callers get a ready-to-use, populated controller in one call — the
/// common case for widget tests that just need seeded stores/products on
/// screen.
Future<GroceryController> buildLoadedGroceryController({
  GroceryRepository repository = const SeededGroceryRepository(),
  GroceryOrderRepository? orderRepository,
  ActivityController? activityController,
  CartStorage<GroceryCartLine>? storage,
  ServicePricingRepository? pricingRepository,
  DateTime Function()? now,
}) async {
  final controller = buildGroceryController(
    repository: repository,
    orderRepository: orderRepository,
    activityController: activityController,
    storage: storage,
    pricingRepository: pricingRepository,
    now: now,
  );
  await controller.load();
  return controller;
}

/// Builds a [PharmacyController] backed by [SeededPharmacyRepository] (or a
/// caller-supplied fake/[repository]) and a fresh in-memory
/// [ActivityController] + [MemoryCartStorage] — shared setup for pharmacy
/// widget/controller tests. Pass [orderRepository], [activityController],
/// [storage] or [now] to override any one of the defaults, e.g. to share an
/// [ActivityController] across controllers or to inspect its recorded
/// items, or to reuse the same [storage] across a "simulated app reload".
///
/// This does not call [PharmacyController.loadProducts] — callers keep
/// control over when the catalog is fetched. Use
/// [buildLoadedPharmacyController] for the common case where a test just
/// wants an already-loaded controller.
PharmacyController buildPharmacyController({
  PharmacyRepository repository = const SeededPharmacyRepository(),
  PharmacyOrderRepository? orderRepository,
  ActivityController? activityController,
  CartStorage<PharmacyCartItem>? storage,
  ServicePricingRepository? pricingRepository,
  DateTime Function()? now,
}) {
  return PharmacyController(
    repository: repository,
    orderRepository: orderRepository,
    activityController: activityController ?? ActivityController(),
    storage: storage ?? MemoryCartStorage<PharmacyCartItem>(),
    // See `buildGroceryController`'s identical note: pre-seeded with a
    // standard default unless the caller overrides it.
    pricingRepository:
        pricingRepository ?? FakeServicePricingRepository.pharmacy(),
    now: now,
  );
}

/// As [buildPharmacyController], but also awaits
/// [PharmacyController.loadProducts] for [storeId] (defaulting to
/// [SeededPharmacyRepository.defaultStoreId]) so callers get a ready-to-use,
/// populated controller in one call — the common case for widget tests that
/// just need seeded products on screen.
Future<PharmacyController> buildLoadedPharmacyController({
  PharmacyRepository repository = const SeededPharmacyRepository(),
  PharmacyOrderRepository? orderRepository,
  ActivityController? activityController,
  CartStorage<PharmacyCartItem>? storage,
  ServicePricingRepository? pricingRepository,
  DateTime Function()? now,
  String storeId = SeededPharmacyRepository.defaultStoreId,
}) async {
  final controller = buildPharmacyController(
    repository: repository,
    orderRepository: orderRepository,
    activityController: activityController,
    storage: storage,
    pricingRepository: pricingRepository,
    now: now,
  );
  await controller.loadProducts(storeId: storeId);
  return controller;
}
