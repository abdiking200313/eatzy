import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/session/account_state_coordinator.dart';
import 'package:chowflow/services/cleaning/presentation/cleaning_controller.dart';
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
    final cleaning = CleaningController(activityController: activity);
    await grocery.load();
    await pharmacy.loadProducts();

    grocery.addProduct(grocery.stores.first.products.first);
    pharmacy.addProduct(pharmacy.products.first);
    final cleaner = cleaning.professionals.first;
    cleaning
      ..selectProfessional(cleaner)
      ..selectSpecialty(cleaner.specialties.first)
      ..selectPlan(cleaner.stayPlans.first)
      ..selectCity('Mogadishu')
      ..setStreetAddress('Taleex Road');
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

    final coordinator = AccountStateCoordinator(
      initialOwnerId: 'user-one',
      activityController: activity,
      groceryController: grocery,
      pharmacyController: pharmacy,
      cleaningController: cleaning,
    );

    expect(coordinator.handleOwnerChanged('user-one'), isFalse);
    expect(grocery.isNotEmpty, isTrue);
    expect(pharmacy.isCartNotEmpty, isTrue);

    expect(coordinator.handleOwnerChanged('user-two'), isTrue);
    expect(activity.items, isEmpty);
    expect(grocery.isEmpty, isTrue);
    expect(pharmacy.isCartEmpty, isTrue);
    expect(cleaning.selectedProfessional, isNull);
    expect(cleaning.streetAddress, isEmpty);
  });
}
