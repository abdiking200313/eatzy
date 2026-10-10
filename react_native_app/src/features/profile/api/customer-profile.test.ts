/**
 * Ports `flutter_app/test/customer_profile_test.dart` (issue #399 / P8-03),
 * plus `displayName` coverage the Dart file exercises only indirectly
 * through `profile_screen_test.dart`.
 */
import { CustomerProfileFormatError, customerDisplayName, parseCustomerProfile } from './customer-profile';

const baseRow = {
  id: 'customer-1',
  firstname: 'Amina',
  lastname: 'Noor',
  phone: '+252 61 234 5678',
};

describe('parseCustomerProfile', () => {
  it('parses a yyyy-MM-dd dob string', () => {
    const profile = parseCustomerProfile({ ...baseRow, dob: '1995-06-15' });

    expect(profile.dob).toEqual(new Date(1995, 5, 15));
  });

  it('tolerates a null dob', () => {
    expect(parseCustomerProfile({ ...baseRow, dob: null }).dob).toBeNull();
  });

  it('tolerates a missing dob key entirely', () => {
    expect(parseCustomerProfile(baseRow).dob).toBeNull();
  });

  it('tolerates an unparsable dob value', () => {
    expect(parseCustomerProfile({ ...baseRow, dob: 'not-a-date' }).dob).toBeNull();
  });

  it('defaults missing optional fields and rejects a missing id', () => {
    const profile = parseCustomerProfile({ id: ' customer-2 ' });

    expect(profile).toEqual({
      id: 'customer-2',
      firstName: '',
      lastName: '',
      phone: '',
      avatarUrl: null,
      dob: null,
    });
    expect(() => parseCustomerProfile({ firstname: 'Amina' })).toThrow(CustomerProfileFormatError);
  });
});

describe('customerDisplayName', () => {
  it('joins first and last name, falling back to "Zivo customer" when both are blank', () => {
    expect(customerDisplayName({ firstName: 'Amina', lastName: 'Noor' })).toBe('Amina Noor');
    expect(customerDisplayName({ firstName: 'Amina', lastName: '' })).toBe('Amina');
    expect(customerDisplayName({ firstName: '', lastName: '' })).toBe('Zivo customer');
  });
});
