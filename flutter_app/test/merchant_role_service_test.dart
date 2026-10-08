import 'package:chowflow/features/merchant/auth/data/merchant_role_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit-tests the role-gating decision at the heart of issue #232's
// acceptance criteria ("a role = 'merchant'/'admin' account signing in ...
// lands on the merchant dashboard ... a role = 'customer' account's
// experience is completely unchanged"), without needing a live Supabase
// project/network access. Ported from `merchant_app`'s
// `merchant_auth_service_test.dart` (originally issue #132); the sign-in/
// sign-out and `NotAMerchantException` coverage from that file no longer
// applies, since there is no second sign-in flow to reject a customer
// account from any more -- see `MerchantRoleService`'s doc comment.
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

    test('rejects null (no profile row found, or the lookup failed)', () {
      expect(isAuthorizedMerchantRole(null), isFalse);
    });

    test('kAllowedMerchantRoles matches the exact profiles_role_check set '
        'minus customer', () {
      // Guards against silently drifting from the migration's check
      // constraint (`role in ('customer', 'merchant', 'admin')`) in
      // supabase/migrations/20260830120000_add_merchant_role_and_store_ownership.sql
      // -- only merchant/admin route to the merchant dashboard.
      expect(kAllowedMerchantRoles, {'merchant', 'admin'});
      expect(kAllowedMerchantRoles.contains('customer'), isFalse);
    });
  });
}
