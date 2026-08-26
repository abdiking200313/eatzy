import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/pharmacy/data/pharmacy_repository.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_checkout.dart';
import 'package:chowflow/services/pharmacy/models/pharmacy_product.dart';
import 'package:chowflow/services/pharmacy/presentation/pharmacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActivityController activityController;
  late PharmacyController controller;

  setUp(() async {
    activityController = ActivityController();
    controller = PharmacyController(
      repository: const SeededPharmacyRepository(),
      activityController: activityController,
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

  test('placeDemoOrder surfaces an error, resets loading, and keeps the cart '
      'when the order repository throws', () async {
    final throwingActivityController = ActivityController();
    final throwingController = PharmacyController(
      repository: const SeededPharmacyRepository(),
      orderRepository: const _ThrowingPharmacyOrderRepository(),
      activityController: throwingActivityController,
      now: () => DateTime.utc(2026, 7, 27, 12),
    );
    await throwingController.loadProducts();
    throwingController.addProduct(throwingController.products.first);

    const details = PharmacyCheckoutDetails(
      customerName: 'Asha Ali',
      phoneNumber: '+252 61 234 5678',
      city: 'Mogadishu',
      district: 'Hodan',
      addressLine: 'Taleex Road, blue gate',
      deliveryInstructions: 'Please call on arrival.',
    );

    final result = await throwingController.placeDemoOrder(details);

    expect(result.isSuccess, isFalse);
    expect(
      result.validation.errorFor('order'),
      contains('The pharmacy order could not be saved'),
    );
    expect(throwingController.isLoading, isFalse);
    expect(throwingController.isCartEmpty, isFalse);
    expect(throwingController.cartItems, hasLength(1));
    expect(throwingActivityController.items, isEmpty);
  });
}

/// A [PharmacyOrderRepository] fake that always fails, simulating a network
/// error, Supabase exception, or RPC validation error surfaced during
/// order placement.
class _ThrowingPharmacyOrderRepository implements PharmacyOrderRepository {
  const _ThrowingPharmacyOrderRepository();

  @override
  Future<String> placeOrder(PharmacyOrderRequest request) {
    throw Exception('Simulated network failure while placing pharmacy order');
  }
}
