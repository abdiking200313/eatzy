import 'package:chowflow/services/food/models/food_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validAddress = FoodDeliveryAddress(
    recipientName: '  Amina Yusuf  ',
    phone: ' +252611234567 ',
    street: ' Maka Al-Mukarama Road ',
    district: ' Hodan ',
    city: ' Mogadishu ',
  );

  const validItems = [FoodOrderLineInput(menuItemId: 'menu-1', quantity: 2)];

  group('FoodOrderRequest.toRpcParams', () {
    test('includes trimmed recipient/address fields for the RPC call', () {
      final params = const FoodOrderRequest(
        restaurantId: 'restaurant-1',
        address: validAddress,
        items: validItems,
      ).toRpcParams();

      expect(params['p_restaurant_id'], 'restaurant-1');
      expect(params['p_recipient_name'], 'Amina Yusuf');
      expect(params['p_phone'], '+252611234567');
      expect(params['p_street'], 'Maka Al-Mukarama Road');
      expect(params['p_district'], 'Hodan');
      expect(params['p_city'], 'Mogadishu');
      expect(params['p_items'], [
        {'menu_item_id': 'menu-1', 'quantity': 2},
      ]);
    });

    test('rejects a missing recipient name', () {
      final request = FoodOrderRequest(
        restaurantId: 'restaurant-1',
        address: const FoodDeliveryAddress(
          recipientName: '',
          phone: '+252611234567',
          street: 'Maka Al-Mukarama Road',
          district: 'Hodan',
          city: 'Mogadishu',
        ),
        items: validItems,
      );

      expect(request.toRpcParams, throwsA(isA<FormatException>()));
    });

    test('rejects a missing street', () {
      final request = FoodOrderRequest(
        restaurantId: 'restaurant-1',
        address: const FoodDeliveryAddress(
          recipientName: 'Amina Yusuf',
          phone: '+252611234567',
          street: '   ',
          district: 'Hodan',
          city: 'Mogadishu',
        ),
        items: validItems,
      );

      expect(request.toRpcParams, throwsA(isA<FormatException>()));
    });

    test('still rejects an empty item list', () {
      const request = FoodOrderRequest(
        restaurantId: 'restaurant-1',
        address: validAddress,
        items: [],
      );

      expect(request.toRpcParams, throwsA(isA<FormatException>()));
    });
  });
}
