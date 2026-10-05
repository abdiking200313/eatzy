import 'package:chowflow/services/food/models/food_models.dart';
import 'package:chowflow/services/shared/models/delivery_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const validItems = [FoodOrderLineInput(menuItemId: 'menu-1', quantity: 2)];

  group('FoodOrderRequest.toRpcParams', () {
    test('sends the trimmed delivery note as the street and leaves name, '
        'phone, district and city blank for the server to fill', () {
      final params = const FoodOrderRequest(
        restaurantId: 'restaurant-1',
        delivery: DeliveryDetails(note: '  Near the mosque, blue gate  '),
        items: validItems,
      ).toRpcParams();

      expect(params['p_restaurant_id'], 'restaurant-1');
      expect(params['p_recipient_name'], '');
      expect(params['p_phone'], '');
      expect(params['p_street'], 'Near the mosque, blue gate');
      expect(params['p_district'], '');
      expect(params['p_city'], '');
      expect(params['p_items'], [
        {'menu_item_id': 'menu-1', 'quantity': 2},
      ]);
    });

    test('the delivery note is optional', () {
      final params = const FoodOrderRequest(
        restaurantId: 'restaurant-1',
        items: validItems,
      ).toRpcParams();

      expect(params['p_street'], '');
    });

    test('still rejects an empty item list', () {
      const request = FoodOrderRequest(restaurantId: 'restaurant-1', items: []);

      expect(request.toRpcParams, throwsA(isA<FormatException>()));
    });
  });

  group('describeOrderSaveError', () {
    test('shows the server message when the profile has no name/phone', () {
      final message = describeOrderSaveError(
        const PostgrestException(
          message: 'Add your name and phone number in Settings before ordering',
        ),
        'fallback',
      );
      expect(message, '$missingContactDetailsMessage.');
    });

    test('falls back to the generic message for any other failure', () {
      expect(
        describeOrderSaveError(
          const PostgrestException(message: 'Restaurant not found'),
          'fallback',
        ),
        'fallback',
      );
      expect(
        describeOrderSaveError(StateError('offline'), 'fallback'),
        'fallback',
      );
    });
  });
}
