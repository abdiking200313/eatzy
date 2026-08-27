import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GroceryController controller;
  late ActivityController activityController;

  setUp(() async {
    activityController = ActivityController();
    controller = GroceryController(
      repository: const SeededGroceryRepository(),
      activityController: activityController,
    );
    await controller.load();
  });

  GroceryProduct product(String id) {
    return controller.stores
        .expand((store) => store.products)
        .firstWhere((product) => product.id == id);
  }

  test('calculates unit and weighted product totals in USD amounts', () {
    final rice = product('bakaal-rice');
    final bananas = product('bakaal-bananas');

    expect(controller.addProduct(rice), GroceryAddResult.added);
    expect(controller.addProduct(bananas), GroceryAddResult.added);
    expect(controller.setQuantity(bananas.id, 1.5), isTrue);

    expect(controller.subtotal, closeTo(11.20, 0.001));
    expect(controller.deliveryFee, 2.50);
    expect(controller.total, closeTo(13.70, 0.001));
  });

  test('does not add unavailable products or exceed available stock', () {
    final tomatoes = product('bakaal-tomatoes');
    final milk = product('bakaal-milk');

    expect(controller.addProduct(tomatoes), GroceryAddResult.unavailable);
    expect(controller.isEmpty, isTrue);

    expect(controller.addProduct(milk), GroceryAddResult.added);
    expect(controller.setQuantity(milk.id, 3), isTrue);
    expect(controller.increment(milk.id), isFalse);
    expect(controller.cart.single.quantity, 3);
  });

  test('requires and records the selected substitution preference', () async {
    controller.addProduct(product('bakaal-rice'));
    const address = GroceryDeliveryAddress(
      recipientName: 'Amina',
      phone: '+252 61 234 5678',
      street: 'Near Taleex Road',
      district: 'Hodan',
      city: 'Mogadishu',
    );

    final missingPreference = await controller.confirmOrder(
      address: address,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: null,
    );
    expect(missingPreference.isSuccess, isFalse);
    expect(
      missingPreference.errors,
      contains('Choose a substitution preference.'),
    );

    final result = await controller.confirmOrder(
      address: address,
      slot: GroceryController.deliverySlots.first,
      substitutionPreference: GrocerySubstitutionPreference.contactMe,
      now: DateTime.utc(2026, 7, 27, 12),
    );

    expect(result.isSuccess, isTrue);
    expect(
      result.confirmation!.substitutionPreference,
      GrocerySubstitutionPreference.contactMe,
    );
    expect(activityController.items, hasLength(1));
    expect(activityController.items.single.serviceId, ServiceId.grocery);
    expect(activityController.items.single.status, 'Demo confirmed');
    expect(controller.isEmpty, isTrue);
  });

  test('checkout validates cart, Somalia address, slot, and preference', () {
    const blankAddress = GroceryDeliveryAddress(
      recipientName: '',
      phone: '',
      street: '',
      district: '',
      city: '',
      country: 'Kenya',
    );

    final errors = controller.validateCheckout(
      address: blankAddress,
      slot: null,
      substitutionPreference: null,
    );

    expect(errors, contains('Add at least one grocery item.'));
    expect(errors, contains('Enter the recipient name.'));
    expect(errors, contains('Enter a valid phone number.'));
    expect(errors, contains('Enter a street or landmark.'));
    expect(errors, contains('Enter a district.'));
    expect(errors, contains('Enter a city.'));
    expect(errors, contains('The MVP currently delivers within Somalia only.'));
    expect(errors, contains('Choose a delivery slot.'));
    expect(errors, contains('Choose a substitution preference.'));
  });

  group('catalog staleness and pull-to-refresh', () {
    test('load does not refetch an already-loaded, fresh catalog', () async {
      final repository = _CountingGroceryRepository();
      final now = DateTime.utc(2026, 8, 27, 12);
      final freshController = GroceryController(
        repository: repository,
        now: () => now,
      );

      await freshController.load();
      expect(repository.fetchCount, 1);

      await freshController.load();
      expect(
        repository.fetchCount,
        1,
        reason: 'a fresh catalog should not be refetched',
      );
    });

    test('load refetches once the catalog goes stale', () async {
      final repository = _CountingGroceryRepository();
      var now = DateTime.utc(2026, 8, 27, 12);
      final staleController = GroceryController(
        repository: repository,
        now: () => now,
      );

      await staleController.load();
      expect(repository.fetchCount, 1);
      expect(staleController.isStale, isFalse);

      now = now.add(GroceryController.catalogStaleAfter);
      expect(staleController.isStale, isTrue);

      await staleController.load();
      expect(repository.fetchCount, 2);
      expect(staleController.isStale, isFalse);
    });

    test(
      'load(forceRefresh: true) always refetches regardless of staleness',
      () async {
        final repository = _CountingGroceryRepository();
        final now = DateTime.utc(2026, 8, 27, 12);
        final forcedController = GroceryController(
          repository: repository,
          now: () => now,
        );

        await forcedController.load();
        expect(repository.fetchCount, 1);

        await forcedController.load(forceRefresh: true);
        expect(repository.fetchCount, 2);
      },
    );
  });
}

class _CountingGroceryRepository implements GroceryRepository {
  int fetchCount = 0;

  @override
  Future<List<GroceryStore>> fetchStores() async {
    fetchCount++;
    return const SeededGroceryRepository().fetchStores();
  }
}
