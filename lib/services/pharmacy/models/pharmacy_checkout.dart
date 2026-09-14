class PharmacyCheckoutDetails {
  const PharmacyCheckoutDetails({
    required this.recipientName,
    required this.phone,
    required this.city,
    required this.district,
    required this.street,
    this.deliveryInstructions = '',
  });

  static const country = 'Somalia';

  /// Field names match the recipient/phone/street/district/city baseline
  /// food (`FoodDeliveryAddress`) and grocery (`GroceryDeliveryAddress`)
  /// already use for the equivalent concept — issue #78 renamed this class
  /// from customerName/phoneNumber/addressLine to match.
  final String recipientName;
  final String phone;
  final String city;
  final String district;
  final String street;
  final String deliveryInstructions;
}

class PharmacyCheckoutValidation {
  const PharmacyCheckoutValidation(this.errors);

  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;
  String? errorFor(String field) => errors[field];
}

class PharmacyCheckoutResult {
  const PharmacyCheckoutResult._({
    required this.isSuccess,
    required this.message,
    this.orderId,
    this.validation = const PharmacyCheckoutValidation({}),
  });

  factory PharmacyCheckoutResult.success({
    required String orderId,
    required String message,
  }) {
    return PharmacyCheckoutResult._(
      isSuccess: true,
      message: message,
      orderId: orderId,
    );
  }

  factory PharmacyCheckoutResult.invalid(
    PharmacyCheckoutValidation validation,
  ) {
    return PharmacyCheckoutResult._(
      isSuccess: false,
      message: 'Please check your checkout details.',
      validation: validation,
    );
  }

  final bool isSuccess;
  final String message;
  final String? orderId;
  final PharmacyCheckoutValidation validation;
}

class PharmacyOrderLineInput {
  const PharmacyOrderLineInput({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;

  Map<String, dynamic> toRpcMap() {
    if (productId.trim().isEmpty) {
      throw const FormatException('A pharmacy product ID is required.');
    }
    if (quantity <= 0) {
      throw const FormatException('Pharmacy quantity must be positive.');
    }
    return {'product_id': productId, 'quantity': quantity};
  }
}

class PharmacyOrderRequest {
  const PharmacyOrderRequest({
    required this.details,
    required this.items,
    this.idempotencyKey,
  });

  final PharmacyCheckoutDetails details;
  final List<PharmacyOrderLineInput> items;

  /// A client-generated token identifying this checkout attempt (issue
  /// #59). `place_pharmacy_order` uses it, together with the caller's
  /// profile, to return the existing order instead of inserting a duplicate
  /// row and decrementing stock again when the same attempt is submitted
  /// more than once. `null` disables that protection for this call.
  final String? idempotencyKey;

  Map<String, dynamic> toRpcParams() {
    if (items.isEmpty) {
      throw const FormatException(
        'A pharmacy order requires at least one item.',
      );
    }
    return {
      'p_recipient_name': details.recipientName.trim(),
      'p_phone': details.phone.trim(),
      'p_city': details.city.trim(),
      'p_district': details.district.trim(),
      'p_street': details.street.trim(),
      'p_delivery_instructions': details.deliveryInstructions.trim(),
      'p_items': items.map((item) => item.toRpcMap()).toList(growable: false),
      'p_idempotency_key': idempotencyKey,
      // p_delivery_address_id (issue #78) is intentionally not sent here:
      // wiring "place order using a saved address" into checkout is a
      // separate, deferred fast-follow — see the PR description. Omitting
      // the key entirely lets the RPC's `default null` apply, identical to
      // passing null explicitly.
    };
  }
}
