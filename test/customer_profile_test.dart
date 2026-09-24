import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerProfile.fromMap', () {
    test('parses a yyyy-MM-dd dob string', () {
      final profile = CustomerProfile.fromMap({
        'id': 'customer-1',
        'firstname': 'Amina',
        'lastname': 'Noor',
        'phone': '+252 61 234 5678',
        'dob': '1995-06-15',
      });

      expect(profile.dob, DateTime(1995, 6, 15));
    });

    test('tolerates a null dob', () {
      final profile = CustomerProfile.fromMap({
        'id': 'customer-1',
        'firstname': 'Amina',
        'lastname': 'Noor',
        'phone': '+252 61 234 5678',
        'dob': null,
      });

      expect(profile.dob, isNull);
    });

    test('tolerates a missing dob key entirely', () {
      final profile = CustomerProfile.fromMap({
        'id': 'customer-1',
        'firstname': 'Amina',
        'lastname': 'Noor',
        'phone': '+252 61 234 5678',
      });

      expect(profile.dob, isNull);
    });

    test('tolerates an unparsable dob value', () {
      final profile = CustomerProfile.fromMap({
        'id': 'customer-1',
        'firstname': 'Amina',
        'lastname': 'Noor',
        'phone': '+252 61 234 5678',
        'dob': 'not-a-date',
      });

      expect(profile.dob, isNull);
    });
  });
}
