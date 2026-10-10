/**
 * Ports the `describeOrderSaveError` cases from
 * `flutter_app/test/food_order_request_test.dart` (issue #378 / P5-03).
 * Not the file's `FoodOrderRequest.toRpcParams` cases -- those are
 * food-vertical request-building, out of this issue's scope.
 */
import { PostgrestError } from '@supabase/supabase-js';

import { describeOrderSaveError, missingContactDetailsMessage } from './order-errors';

function postgrestError(message: string): PostgrestError {
  return new PostgrestError({ message, details: '', hint: '', code: '' });
}

describe('describeOrderSaveError', () => {
  it('shows the server message when the profile has no name/phone', () => {
    const message = describeOrderSaveError(
      postgrestError('Add your name and phone number in Settings before ordering'),
      'fallback',
    );

    expect(message).toBe(`${missingContactDetailsMessage}.`);
  });

  it('falls back to the generic message for any other failure', () => {
    expect(describeOrderSaveError(postgrestError('Restaurant not found'), 'fallback')).toBe('fallback');
    expect(describeOrderSaveError(new Error('offline'), 'fallback')).toBe('fallback');
  });
});
