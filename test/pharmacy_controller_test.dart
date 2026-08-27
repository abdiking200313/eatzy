import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_cart_item.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_checkout.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cart_storage.dart';

void main() {
  late ActivityController activityController;
  late PharmacyController controller;
  late MemoryCartStorage<PharmacyCartItem> storage;

  setUp(() async {
    activityController = ActivityController();
    storage = MemoryCartStorage<PharmacyCartItem>();
    controller = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: activityController,
      storage: storage,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await controller.loadProducts();
  });

  test('pharmacy cart adds, adjusts, removes, and calculates USD totals', () {
    final paracetamol = controller.products.first;

    expect(controller.addProduct(paracetamol), PharmacyCartAddResult.added);
    expect(
      controller.addProduct(paracetamol),
      PharmacyCartAddResult.quantityIncreased,
    );

    expect(controller.cartItems, hasLength(1));
    expect(controller.itemCount, 2);
    expect(controller.subtotal, 5.50);
    expect(controller.total, 8.00);

    controller.decrement(paracetamol.id);
    expect(controller.cartItems.single.quantity, 1);

    controller.removeProduct(paracetamol.id);
    expect(controller.isCartEmpty, isTrue);
    expect(controller.total, 0);
  });

  test('an unavailable OTC product cannot be added', () {
    final unavailable = controller.products.firstWhere(
      (product) => !product.isAvailable,
    );

    expect(
      controller.addProduct(unavailable),
      PharmacyCartAddResult.unavailable,
    );
    expect(controller.isCartEmpty, isTrue);
  });

  test('a non-OTC product is rejected by the domain controller', () {
    const prescriptionProduct = PharmacyProduct(
      id: 'prescription-only',
      name: 'Prescription medicine',
      description: 'Not eligible for the OTC launch.',
      category: 'Prescription',
      unitPrice: 10,
      stockQuantity: 5,
      saleType: PharmacySaleType.prescriptionOnly,
    );

    expect(
      controller.addProduct(prescriptionProduct),
      PharmacyCartAddResult.notOverTheCounter,
    );
    expect(controller.isCartEmpty, isTrue);
  });

  test('checkout validates cart and Somalia delivery details', () {
    const emptyDetails = PharmacyCheckoutDetails(
      customerName: '',
      phoneNumber: '12',
      city: '',
      district: '',
      addressLine: '',
    );

    final validation = controller.validateCheckout(emptyDetails);

    expect(validation.isValid, isFalse);
    expect(validation.errorFor('cart'), isNotNull);
    expect(validation.errorFor('customerName'), isNotNull);
    expect(validation.errorFor('phoneNumber'), isNotNull);
    expect(validation.errorFor('city'), contains('Somalia'));
    expect(validation.errorFor('district'), isNotNull);
    expect(validation.errorFor('addressLine'), isNotNull);
    expect(PharmacyCheckoutDetails.country, 'Somalia');
  });

  test('demo checkout records pharmacy activity and clears its cart', () async {
    controller.addProduct(controller.products.first);
    const details = PharmacyCheckoutDetails(
      customerName: 'Asha Ali',
      phoneNumber: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      addressLine: 'Taleex Road, blue gate',
      deliveryInstructions: 'Please call on arrival.',
    );

    final result = await controller.placeDemoOrder(details);

    expect(result.isSuccess, isTrue);
    expect(result.message, contains('No payment was processed'));
    expect(controller.isCartEmpty, isTrue);
    expect(activityController.items, hasLength(1));
    expect(activityController.items.single.serviceId, ServiceId.pharmacy);
    expect(activityController.items.single.status, 'Demo confirmed');
    expect(activityController.items.single.amount, 5.25);
  });

  test('pharmacy cart survives a simulated app reload', () async {
    await controller.loadForOwner('user-1');
    final paracetamol = controller.products.first;
    controller.addProduct(paracetamol);
    controller.increment(paracetamol.id);
    await controller.pendingCartWrite;

    // Simulate the app restarting: a brand new controller backed by the
    // same underlying storage should restore the persisted cart.
    final restarted = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: activityController,
      storage: storage,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await restarted.loadProducts();
    await restarted.loadForOwner('user-1');

    expect(restarted.cartItems, hasLength(1));
    expect(restarted.cartItems.single.product.id, paracetamol.id);
    expect(restarted.cartItems.single.quantity, 2);
  });

  test('switching accounts clears and reloads the pharmacy cart', () async {
    await controller.loadForOwner('user-1');
    final paracetamol = controller.products.first;
    controller.addProduct(paracetamol);
    expect(controller.isCartNotEmpty, isTrue);
    await controller.pendingCartWrite;

    await controller.loadForOwner('user-2');
    expect(controller.isCartEmpty, isTrue);

    final otherProduct = controller.products[1];
    controller.addProduct(otherProduct);
    await controller.pendingCartWrite;
    await controller.loadForOwner('user-1');
    expect(controller.cartItems.single.product.id, paracetamol.id);

    await controller.loadForOwner('user-2');
    expect(controller.cartItems.single.product.id, otherProduct.id);
  });
}
