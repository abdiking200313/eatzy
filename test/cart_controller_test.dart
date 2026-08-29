import 'package:chowflow/features/cart/models/cart_item.dart';
import 'package:chowflow/features/cart/presentation/cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  const burger = CartItem(
    menuItemId: 'burger-1',
    restaurantId: 'restaurant-1',
    restaurantName: 'Test Kitchen',
    name: 'Classic Burger',
    unitPrice: 10,
    imageUrl: '',
  );

  test('adding the same menu item increases its quantity and totals', () async {
    final controller = CartController(storage: MemoryCartStorage<CartItem>());
    await controller.loadForOwner('user-1');

    expect(await controller.addItem(burger), CartAddResult.added);
    expect(await controller.addItem(burger), CartAddResult.quantityIncreased);

    expect(controller.items, hasLength(1));
    expect(controller.items.single.quantity, 2);
    expect(controller.itemCount, 2);
    expect(controller.subtotal, 20);
    expect(controller.tax, 2);
    expect(controller.deliveryFee, 4.99);
    expect(controller.total, closeTo(26.99, 0.001));
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
        unitPrice: 12,
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
