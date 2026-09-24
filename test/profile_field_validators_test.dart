import 'package:chowflow/features/profile/models/profile_field_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateFirstName', () {
    test('rejects an empty value', () {
      expect(validateFirstName(''), 'Enter your first name.');
    });

    test('rejects a whitespace-only value', () {
      expect(validateFirstName('   '), 'Enter your first name.');
    });

    test('accepts a non-empty value', () {
      expect(validateFirstName('Amina'), isNull);
    });
  });

  group('validateLastName', () {
    test('rejects an empty value', () {
      expect(validateLastName(''), 'Enter your last name.');
    });

    test('rejects a whitespace-only value', () {
      expect(validateLastName('   '), 'Enter your last name.');
    });

    test('accepts a non-empty value', () {
      expect(validateLastName('Noor'), isNull);
    });
  });

  group('validatePhone', () {
    test('rejects an empty value', () {
      expect(validatePhone(''), 'Enter your phone number.');
    });

    test('rejects a whitespace-only value', () {
      expect(validatePhone('   '), 'Enter your phone number.');
    });

    test('rejects an implausibly short number', () {
      expect(validatePhone('123'), 'Please enter a valid phone number.');
    });

    test('rejects letters', () {
      expect(
        validatePhone('not-a-phone'),
        'Please enter a valid phone number.',
      );
    });

    test('accepts a plausible international number', () {
      expect(validatePhone('+252 61 234 5678'), isNull);
    });

    test('accepts a plausible number with dashes and no country code', () {
      expect(validatePhone('612-345-678'), isNull);
    });
  });

  group('validateDob', () {
    test('rejects a null value', () {
      expect(validateDob(null), 'Choose your date of birth.');
    });

    test('rejects a date in the future', () {
      final future = DateTime.now().add(const Duration(days: 1));
      expect(validateDob(future), "Date of birth can't be in the future.");
    });

    test('accepts a date in the past', () {
      expect(validateDob(DateTime(1995, 6, 15)), isNull);
    });

    test('accepts today', () {
      final today = DateTime.now();
      expect(validateDob(today), isNull);
    });
  });

  group('validateEmail', () {
    test('rejects an empty value', () {
      expect(validateEmail(''), 'Enter your email address.');
    });

    test('rejects a whitespace-only value', () {
      expect(validateEmail('   '), 'Enter your email address.');
    });

    test('rejects a value with no @', () {
      expect(
        validateEmail('amina.zivo.app'),
        'Please enter a valid email address.',
      );
    });

    test('rejects a value with no domain suffix', () {
      expect(
        validateEmail('amina@zivo'),
        'Please enter a valid email address.',
      );
    });

    test('accepts a plausible address', () {
      expect(validateEmail('amina@zivo.app'), isNull);
    });
  });
}
