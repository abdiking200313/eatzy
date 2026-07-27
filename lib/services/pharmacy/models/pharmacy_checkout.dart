class PharmacyCheckoutDetails {
  const PharmacyCheckoutDetails({
    required this.customerName,
    required this.phoneNumber,
    required this.city,
    required this.district,
    required this.addressLine,
    this.deliveryInstructions = '',
  });

  static const country = 'Somalia';

  final String customerName;
  final String phoneNumber;
  final String city;
  final String district;
  final String addressLine;
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
  const PharmacyOrderRequest({required this.details, required this.items});

  final PharmacyCheckoutDetails details;
  final List<PharmacyOrderLineInput> items;

  Map<String, dynamic> toRpcParams() {
    if (items.isEmpty) {
      throw const FormatException(
        'A pharmacy order requires at least one item.',
      );
    }
    return {
      'p_customer_name': details.customerName.trim(),
      'p_phone_number': details.phoneNumber.trim(),
      'p_city': details.city.trim(),
      'p_district': details.district.trim(),
      'p_address_line': details.addressLine.trim(),
      'p_delivery_instructions': details.deliveryInstructions.trim(),
      'p_items': items.map((item) => item.toRpcMap()).toList(growable: false),
    };
  }
}
