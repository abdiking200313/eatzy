/**
 * Ports the `DeliveryDetails.toRpcParams` behavior from
 * `flutter_app/lib/services/shared/models/delivery_details.dart` (issue
 * #381 / P5-06) -- no dedicated Flutter test file exists for this model,
 * so coverage is written directly from its own documented behavior.
 */
import { deliveryDetailsToRpcParams, EMPTY_DELIVERY_DETAILS } from './delivery-details';

describe('deliveryDetailsToRpcParams', () => {
  it('puts the trimmed note in p_street and leaves name/phone/city/district empty', () => {
    expect(deliveryDetailsToRpcParams({ note: '  Blue gate, ring bell  ' })).toEqual({
      p_recipient_name: '',
      p_phone: '',
      p_street: 'Blue gate, ring bell',
      p_district: '',
      p_city: '',
    });
  });

  it('handles an empty note', () => {
    expect(deliveryDetailsToRpcParams(EMPTY_DELIVERY_DETAILS)).toEqual({
      p_recipient_name: '',
      p_phone: '',
      p_street: '',
      p_district: '',
      p_city: '',
    });
  });
});
