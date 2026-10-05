import 'dart:async';

import '../../../app/service_module.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/error_reporting/error_reporter.dart';
import '../../shared/data/idempotency_key.dart';
import '../../shared/data/rpc_helpers.dart';
import '../../shared/models/delivery_details.dart';
import '../../shared/presentation/confirm_order_flow.dart';
import '../data/grocery_repository.dart';
import '../models/grocery_models.dart';

/// Validates and places a grocery checkout, owning the state around a
/// submission in flight ([isSubmitting]) and the last confirmed order
/// ([lastConfirmation]).
///
/// Extracted from `GroceryController` (issue #293) to separate checkout
/// orchestration from cart/quantity rules (see `GroceryCart`) and catalog
/// loading (see `GroceryCatalog`). `GroceryController` still owns the cart
/// itself, pricing, and deciding when to call `notifyListeners`
/// ([confirmOrder] takes an [onChanged] callback for exactly that, called at
/// the same points the unextracted method did).
class GroceryCheckout {
  GroceryCheckout({
    required GroceryOrderRepository? orderRepository,
    required ActivityController activityController,
    required GroceryStoreType storeType,
  }) : _orderRepository = orderRepository,
       _activityController = activityController,
       _storeType = storeType;

  final GroceryOrderRepository? _orderRepository;
  final ActivityController _activityController;
  final GroceryStoreType _storeType;

  bool _isSubmitting = false;
  GroceryOrderConfirmation? _lastConfirmation;

  /// Whether a [confirmOrder] call is currently in flight. The checkout
  /// screen disables its submit button while this is true — see issue #59 —
  /// and [confirmOrder] itself also refuses to start a second submission
  /// while this is true, as a belt-and-braces guard against a double-tap or
  /// a second programmatic call racing the first one.
  bool get isSubmitting => _isSubmitting;
  GroceryOrderConfirmation? get lastConfirmation => _lastConfirmation;

  List<String> validate({
    required bool cartIsEmpty,
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
  }) {
    final errors = <String>[];
    if (cartIsEmpty) {
      errors.add('Add at least one grocery item.');
    }
    if (slot == null) {
      errors.add('Choose a delivery slot.');
    }
    if (substitutionPreference == null) {
      errors.add('Choose a substitution preference.');
    }
    return errors;
  }

  /// Validates (via the already-computed [validationErrors]) and, once
  /// valid, places the order through the shared [confirmDemoOrder] flow,
  /// records activity, and clears the cart.
  ///
  /// A no-op — without touching submission state — while a previous call is
  /// still in flight (see [isSubmitting]).
  ///
  /// [storeId], [storeName], [subtotal], [deliveryFee], [total] and [items]
  /// are the caller's already-computed cart/pricing snapshot, taken before
  /// [clearCart] runs. [clearCart] is awaited before this resolves,
  /// matching [confirmDemoOrder]'s contract.
  ///
  /// [idempotencyKey] identifies this checkout *attempt* and is forwarded
  /// to `place_grocery_order` so a retried submission (the same key)
  /// returns the existing order instead of creating a duplicate and
  /// decrementing stock again. Callers should generate one per attempt
  /// (e.g. once per checkout screen visit) and keep passing the same value
  /// across retries of that attempt; when omitted, a fresh key is generated
  /// for this call only, which gives no protection against a retry that
  /// calls this method again.
  Future<GroceryCheckoutResult> confirmOrder({
    required List<String> validationErrors,
    required String? storeId,
    required String? storeName,
    required int subtotal,
    required int? deliveryFee,
    required int? total,
    required List<GroceryOrderLineInput> items,
    DeliveryDetails delivery = const DeliveryDetails(),
    required GroceryDeliverySlot? slot,
    required GrocerySubstitutionPreference? substitutionPreference,
    required FutureOr<void> Function() clearCart,
    String? idempotencyKey,
    DateTime? now,
    required void Function() onChanged,
  }) {
    if (_isSubmitting) {
      return Future.value(GroceryCheckoutResult.invalid(const []));
    }

    final createdAt = now ?? DateTime.now();
    final resolvedIdempotencyKey = idempotencyKey ?? generateIdempotencyKey();
    GroceryOrderConfirmation? confirmation;

    if (validationErrors.isNotEmpty) {
      return Future.value(GroceryCheckoutResult.invalid(validationErrors));
    }

    _isSubmitting = true;
    onChanged();

    return confirmDemoOrder<GroceryCheckoutResult, List<String>, PlacedOrder>(
      validation: validationErrors,
      isValid: (validation) => validation.isEmpty,
      onInvalid: (validation) => GroceryCheckoutResult.invalid(validation),
      placeOrder: () =>
          _orderRepository?.placeOrder(
            GroceryOrderRequest(
              storeId: storeId!,
              deliverySlotId: slot!.id,
              delivery: delivery,
              substitutionPreference: substitutionPreference!,
              items: items,
              idempotencyKey: resolvedIdempotencyKey,
            ),
          ) ??
          Future.value(null),
      // `?? 0` only matters if pricing has never loaded (issue #279) — this
      // demo-only fallback (no real repository configured) never represents
      // a real charge either way.
      fallbackOrder: () => PlacedOrder(
        orderId: 'grocery-${createdAt.microsecondsSinceEpoch}',
        subtotal: subtotal,
        deliveryFee: deliveryFee ?? 0,
        tax: 0,
        total: total ?? (subtotal + (deliveryFee ?? 0)),
      ),
      onSaveFailed: (error, stackTrace) {
        ErrorReporting.instance.reportError(
          error,
          stackTrace,
          context: 'GroceryController.confirmOrder',
        );
        return GroceryCheckoutResult.invalid([
          describeOrderSaveError(
            error,
            'The grocery order could not be saved. Please try again.',
          ),
        ]);
      },
      // `order.total` is the RPC's authoritative, server-computed total
      // (issue #60) — not the client-computed `total`, which can be stale
      // if a product price changed between the cart being built and this
      // checkout being confirmed.
      recordActivity: (order) {
        confirmation = GroceryOrderConfirmation(
          orderId: order.orderId,
          createdAt: createdAt,
          amount: order.total,
          slot: slot!,
          substitutionPreference: substitutionPreference!,
        );
        _activityController.record(
          ActivityItem(
            id: order.orderId,
            serviceId: ServiceId.grocery,
            title: storeName ?? 'Grocery order',
            subtitle: '${slot.label}, ${slot.detail}',
            status: 'Confirmed',
            occurredAt: createdAt,
            amount: order.total,
            detailsRoute: _storeType.listRoute,
            paymentMethod: 'cash_on_delivery',
            paymentStatus: 'pending_collection',
          ),
        );
      },
      clearCart: clearCart,
      onConfirmed: (order) {
        _lastConfirmation = confirmation;
        onChanged();
        return GroceryCheckoutResult.confirmed(confirmation!);
      },
    ).whenComplete(() {
      _isSubmitting = false;
      onChanged();
    });
  }

  /// Resets [lastConfirmation], e.g. on an account switch
  /// (`GroceryController.resetSessionState`) or once a new item is added to
  /// a cart that previously confirmed an order
  /// (`GroceryController.addProduct`).
  void resetConfirmation() {
    _lastConfirmation = null;
  }
}
