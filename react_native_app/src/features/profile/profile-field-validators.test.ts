/** Ports `flutter_app/test/profile_field_validators_test.dart` (issue #400 / P8-04), case for case. */
import {
  validateDob,
  validateEmail,
  validateFirstName,
  validateLastName,
  validatePhone,
} from './profile-field-validators';

describe('validateFirstName', () => {
  test('rejects an empty value', () => {
    expect(validateFirstName('')).toBe('Enter your first name.');
  });

  test('rejects a whitespace-only value', () => {
    expect(validateFirstName('   ')).toBe('Enter your first name.');
  });

  test('accepts a non-empty value', () => {
    expect(validateFirstName('Amina')).toBeNull();
  });
});

describe('validateLastName', () => {
  test('rejects an empty value', () => {
    expect(validateLastName('')).toBe('Enter your last name.');
  });

  test('rejects a whitespace-only value', () => {
    expect(validateLastName('   ')).toBe('Enter your last name.');
  });

  test('accepts a non-empty value', () => {
    expect(validateLastName('Noor')).toBeNull();
  });
});

describe('validatePhone', () => {
  test('rejects an empty value', () => {
    expect(validatePhone('')).toBe('Enter your phone number.');
  });

  test('rejects a whitespace-only value', () => {
    expect(validatePhone('   ')).toBe('Enter your phone number.');
  });

  test('rejects an implausibly short number', () => {
    expect(validatePhone('123')).toBe('Please enter a valid phone number.');
  });

  test('rejects letters', () => {
    expect(validatePhone('not-a-phone')).toBe('Please enter a valid phone number.');
  });

  test('accepts a plausible international number', () => {
    expect(validatePhone('+252 61 234 5678')).toBeNull();
  });

  test('accepts a plausible number with dashes and no country code', () => {
    expect(validatePhone('612-345-678')).toBeNull();
  });
});

describe('validateDob', () => {
  test('rejects a null value', () => {
    expect(validateDob(null)).toBe('Choose your date of birth.');
  });

  test('rejects a date in the future', () => {
    const future = new Date(Date.now() + 24 * 60 * 60 * 1000);
    expect(validateDob(future)).toBe("Date of birth can't be in the future.");
  });

  test('accepts a date in the past', () => {
    expect(validateDob(new Date(1995, 5, 15))).toBeNull();
  });

  test('accepts today', () => {
    expect(validateDob(new Date())).toBeNull();
  });
});

describe('validateEmail', () => {
  test('rejects an empty value', () => {
    expect(validateEmail('')).toBe('Enter your email address.');
  });

  test('rejects a whitespace-only value', () => {
    expect(validateEmail('   ')).toBe('Enter your email address.');
  });

  test('rejects a value with no @', () => {
    expect(validateEmail('amina.zivo.app')).toBe('Please enter a valid email address.');
  });

  test('rejects a value with no domain suffix', () => {
    expect(validateEmail('amina@zivo')).toBe('Please enter a valid email address.');
  });

  test('accepts a plausible address', () => {
    expect(validateEmail('amina@zivo.app')).toBeNull();
  });
});
