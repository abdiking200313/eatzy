import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/auth/data/merchant_auth_service.dart';

// Unit-tests the role-gating decision at the heart of issue #132's
// acceptance criteria ("...gated to `profiles.role in ('merchant',
// 'admin')`... a customer-role account should not be able to sign into
// this app"), without needing a live Supabase project/network access,
// which this sandbox does not have.
void main() {
  group('isAuthorizedMerchantRole', () {
    test('allows merchant', () {
      expect(isAuthorizedMerchantRole('merchant'), isTrue);
    });

    test('allows admin', () {
      expect(isAuthorizedMerchantRole('admin'), isTrue);
    });

    test('rejects customer', () {
      expect(isAuthorizedMerchantRole('customer'), isFalse);
    });

    test('rejects an unknown/unexpected role string', () {
      expect(isAuthorizedMerchantRole('super_admin'), isFalse);
    });

    test('rejects null (no profile row found)', () {
      expect(isAuthorizedMerchantRole(null), isFalse);
    });

    test('kAllowedMerchantRoles matches the exact profiles_role_check set '
        'minus customer', () {
      // Guards against silently drifting from the migration's check
      // constraint (`role in ('customer', 'merchant', 'admin')`) in
      // supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql
      // on the main app -- only merchant/admin belong here.
      expect(kAllowedMerchantRoles, {'merchant', 'admin'});
      expect(kAllowedMerchantRoles.contains('customer'), isFalse);
    });
  });

  group('NotAMerchantException', () {
    test('toString includes the rejected role for diagnostics', () {
      const exception = NotAMerchantException('customer');
      expect(exception.toString(), contains('customer'));
    });

    test('toString handles a null role', () {
      const exception = NotAMerchantException(null);
      expect(exception.toString(), contains('null'));
    });
  });
}
