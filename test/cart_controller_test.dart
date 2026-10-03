import 'package:chowflow/services/food/models/cart_item.dart';
import 'package:chowflow/services/food/presentation/cart_controller.dart';
import 'package:chowflow/services/shared/models/service_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_service_pricing_repository.dart';
import 'helpers/memory_cart_storage.dart';

void main() {
  const burger = CartItem(
    menuItemId: 'burger-1',
    restaurantId: 'restaurant-1',
    restaurantName: 'Test Kitchen',
    name: 'Classic Burger',
    unitPrice: 1000,
    imageUrl: '',
  );

  /// Builds a [CartController] with pricing pre-seeded to the historical
  /// hardcoded default (499 cents delivery, 10% tax — issue #279), so tests
  /// that don't care about pricing keep seeing the same numbers as before
  /// the hardcoded constants were removed.
  CartController buildController({
    MemoryCartStorage<CartItem>? storage,
    FakeServicePricingRepository? pricingRepository,
  }) => CartController(
    storage: storage ?? MemoryCartStorage<CartItem>(),
    pricingRepository: pricingRepository ?? FakeServicePricingRepository.food(),
  );

  test('adding the same menu item increases its quantity and totals', () async {
    final controller = buildController();
    await controller.loadForOwner('user-1');

    expect(await controller.addItem(burger), CartAddResult.added);
    expect(await controller.addItem(burger), CartAddResult.quantityIncreased);

    expect(controller.items, hasLength(1));
    expect(controller.items.single.quantity, 2);
    expect(controller.itemCount, 2);
    expect(controller.subtotal, 2000);
    expect(controller.tax, 200);
    expect(controller.deliveryFee, 499);
    expect(controller.total, 2699);
  });

  test('changing the pricing repository changes the displayed fee/tax estimate '
      '(issue #279)', () async {
    final pricingRepository = FakeServicePricingRepository.food(
      deliveryFeeCents: 999,
      taxRate: 0.05,
    );
    final controller = buildController(pricingRepository: pricingRepository);
    await controller.loadForOwner('user-1');
    await controller.addItem(burger);

    expect(controller.deliveryFee, 999);
    expect(controller.tax, 50);
    expect(controller.total, 1000 + 50 + 999);

    // The owner changes the `service_pricing` row — simulated here by
    // mutating the fake repository the same way a fresh load would pick
    // up a changed table row — and the estimate reflects it immediately,
    // with no stale hardcoded Dart constant left to diverge from it.
    pricingRepository.set(
      'food',
      const ServicePricing(
        serviceId: 'food',
        deliveryFeeCents: 150,
        taxRate: 0.20,
      ),
    );

    expect(controller.deliveryFee, 150);
    expect(controller.tax, 200);
    expect(controller.total, 1000 + 200 + 150);
  });

  test('reports fees/tax/total as unknown (null) until pricing has ever loaded '
      '(issue #279)', () async {
    final controller = buildController(
      pricingRepository: FakeServicePricingRepository.unconfigured(),
    );
    await controller.loadForOwner('user-1');
    await controller.addItem(burger);

    expect(controller.deliveryFee, isNull);
    expect(controller.tax, isNull);
    expect(controller.total, isNull);
    // An empty cart is always known to cost nothing, regardless of
    // whether pricing has loaded.
    await controller.remove(burger.menuItemId);
    expect(controller.deliveryFee, 0);
    expect(controller.tax, 0);
    expect(controller.total, 0);
  });

  test('cart restores from storage for the same signed-in account', () async {
    final storage = MemoryCartStorage<CartItem>();
    final original = CartController(storage: storage);
    await original.loadForOwner('user-1');
    await original.addItem(burger);
    await original.increment(burger.menuItemId);

    final restored = CartController(storage: storage);
    await restored.loadForOwner('user-1');

    expect(restored.items, hasLength(1));
    expect(restored.items.single.name, burger.name);
    expect(restored.items.single.quantity, 2);

    await restored.loadForOwner('user-2');
    expect(restored.items, isEmpty);
  });

  test(
    'a different restaurant requires confirmation before replacement',
    () async {
      const otherRestaurantItem = CartItem(
        menuItemId: 'pizza-1',
        restaurantId: 'restaurant-2',
        restaurantName: 'Pizza Place',
        name: 'Margherita',
        unitPrice: 1200,
        imageUrl: '',
      );
      final controller = CartController(storage: MemoryCartStorage<CartItem>());
      await controller.loadForOwner('user-1');
      await controller.addItem(burger);

      expect(
        await controller.addItem(otherRestaurantItem),
        CartAddResult.restaurantConflict,
      );
      expect(controller.items.single.menuItemId, burger.menuItemId);

      expect(
        await controller.addItem(
          otherRestaurantItem,
          replaceRestaurantCart: true,
        ),
        CartAddResult.replacedRestaurant,
      );
      expect(controller.items.single.menuItemId, 'pizza-1');
    },
  );

  test('quantity changes, removal, and clear are persisted', () async {
    final storage = MemoryCartStorage<CartItem>();
    final controller = CartController(storage: storage);
    await controller.loadForOwner('user-1');
    await controller.addItem(burger);

    await controller.increment(burger.menuItemId);
    await controller.decrement(burger.menuItemId);
    expect(controller.items.single.quantity, 1);

    await controller.remove(burger.menuItemId);
    expect(controller.isEmpty, isTrue);

    await controller.addItem(burger);
    await controller.clear();

    final restored = CartController(storage: storage);
    await restored.loadForOwner('user-1');
    expect(restored.isEmpty, isTrue);
  });
}
