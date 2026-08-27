import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/grocery/data/grocery_repository.dart';
import 'package:chowflow/services/grocery/models/grocery_models.dart';
import 'package:chowflow/services/grocery/presentation/grocery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  late GroceryController controller;
  late ActivityController activityController;
  late MemoryCartStorage<GroceryCartLine> storage;

  setUp(() async {
    activityController = ActivityController();
    storage = MemoryCartStorage<GroceryCartLine>();
    controller = GroceryController(
      repository: const SeededGroceryRepository(),
      activityController: activityController,
      storage: storage,
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

  test('grocery cart survives a simulated app reload', () async {
    await controller.loadForOwner('user-1');
    final rice = product('bakaal-rice');
    controller.addProduct(rice);
    controller.setQuantity(rice.id, 2);
    await controller.pendingCartWrite;

    // Simulate the app restarting: a brand new controller backed by the
    // same underlying storage should restore the persisted cart.
    final restarted = GroceryController(
      repository: const SeededGroceryRepository(),
      activityController: activityController,
      storage: storage,
    );
    await restarted.load();
    await restarted.loadForOwner('user-1');

    expect(restarted.cart, hasLength(1));
    expect(restarted.cart.single.product.id, rice.id);
    expect(restarted.cart.single.quantity, 2);
  });

  test('switching accounts clears and reloads the grocery cart', () async {
    await controller.loadForOwner('user-1');
    controller.addProduct(product('bakaal-rice'));
    expect(controller.isNotEmpty, isTrue);
    await controller.pendingCartWrite;

    await controller.loadForOwner('user-2');
    expect(controller.isEmpty, isTrue);

    controller.addProduct(product('bakaal-bananas'));
    await controller.pendingCartWrite;
    await controller.loadForOwner('user-1');
    expect(controller.cart.single.product.id, 'bakaal-rice');

    await controller.loadForOwner('user-2');
    expect(controller.cart.single.product.id, 'bakaal-bananas');
  });
}
