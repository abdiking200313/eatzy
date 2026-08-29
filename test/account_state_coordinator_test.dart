import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/session/account_state_coordinator.dart';
import 'package:chowflow/platform/session/session_reset_registry.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an account change clears every account-scoped MVP state', () async {
    final activity = ActivityController();
    final grocery = GroceryController(
      repository: const SeededGroceryRepository(),
      activityController: activity,
    );
    final pharmacy = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: activity,
    );
    await grocery.load();
    await pharmacy.loadProducts();

    grocery.addProduct(grocery.stores.first.products.first);
    pharmacy.addProduct(pharmacy.products.first);
    activity.record(
      ActivityItem(
        id: 'activity-1',
        serviceId: ServiceId.food,
        title: 'Food order',
        status: 'Confirmed',
        occurredAt: DateTime.utc(2026, 7, 27),
        amount: 12,
        detailsRoute: '/food',
      ),
    );

    // A fresh registry per test, mirroring how each service module's
    // controller singleton self-registers in the real app — the shared
    // coordinator never imports GroceryController/PharmacyController
    // directly.
    final registry = SessionResetRegistry();
    registry.register(grocery.resetSessionState);
    registry.register(pharmacy.resetSessionState);

    final coordinator = AccountStateCoordinator(
      initialOwnerId: 'user-one',
      activityController: activity,
      registry: registry,
    );

    expect(coordinator.handleOwnerChanged('user-one'), isFalse);
    expect(grocery.isNotEmpty, isTrue);
    expect(pharmacy.isCartNotEmpty, isTrue);

    expect(coordinator.handleOwnerChanged('user-two'), isTrue);
    expect(activity.items, isEmpty);
    expect(grocery.isEmpty, isTrue);
    expect(pharmacy.isCartEmpty, isTrue);
  });
}
