import 'package:chowflow/features/merchant/admin/data/admin_accounts_repository.dart';
import 'package:chowflow/features/merchant/admin/models/admin_account_lookup.dart';
import 'package:chowflow/features/merchant/admin/presentation/admin_accounts_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

// Unit-tests `AdminAccountsController`'s lookup/role-change bookkeeping
// (requested directly by the app owner, 2026-09-18), against the fake
// repository rather than a live Supabase project (no network access in this
// sandbox).
void main() {
  const merchant = AdminAccountLookup(
    id: 'profile-1',
    firstName: 'Amal',
    lastName: 'Hassan',
    role: 'customer',
  );

  group('lookup', () {
    test('populates result and hasSearched on a match', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(
          accountsByEmail: {'amal@example.com': merchant},
        ),
      );

      expect(controller.hasSearched, isFalse);
      await controller.lookup('amal@example.com');

      expect(controller.hasSearched, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.loadError, isNull);
      expect(controller.result, merchant);
    });

    test('hasSearched is true with a null result (no match)', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(),
      );

      await controller.lookup('nobody@example.com');

      expect(controller.hasSearched, isTrue);
      expect(controller.result, isNull);
      expect(controller.loadError, isNull);
    });

    test('sets loadError and clears result on failure', () async {
      final repository =
          FakeAdminAccountsRepository(
              accountsByEmail: {'amal@example.com': merchant},
            )
            ..failureToThrow = const AdminAccountsException(
              'Admin privileges required',
            );
      final controller = AdminAccountsController(repository: repository);

      await controller.lookup('amal@example.com');

      expect(controller.isLoading, isFalse);
      expect(controller.loadError, 'Admin privileges required');
      expect(controller.result, isNull);
      expect(controller.hasSearched, isFalse);
    });

    test('a later failed lookup clears a previous successful result', () async {
      final repository = FakeAdminAccountsRepository(
        accountsByEmail: {'amal@example.com': merchant},
      );
      final controller = AdminAccountsController(repository: repository);
      await controller.lookup('amal@example.com');
      expect(controller.result, isNotNull);

      repository.failureToThrow = Exception('network down');
      await controller.lookup('amal@example.com');

      expect(controller.result, isNull);
      expect(controller.loadError, isNotNull);
    });
  });

  group('setRole', () {
    test('returns false with no account loaded', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(),
      );

      final succeeded = await controller.setRole('merchant');

      expect(succeeded, isFalse);
    });

    test('updates result on success', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(
          accountsByEmail: {'amal@example.com': merchant},
        ),
      );
      await controller.lookup('amal@example.com');

      final succeeded = await controller.setRole('merchant');

      expect(succeeded, isTrue);
      expect(controller.result!.role, 'merchant');
      expect(controller.saveError, isNull);
    });

    test('returns false and sets saveError on rejection', () async {
      final repository = FakeAdminAccountsRepository(
        accountsByEmail: {'amal@example.com': merchant},
      );
      final controller = AdminAccountsController(repository: repository);
      await controller.lookup('amal@example.com');
      repository.failureToThrow = const AdminAccountsException(
        'Cannot remove the last remaining admin',
      );

      final succeeded = await controller.setRole('admin');

      expect(succeeded, isFalse);
      expect(controller.saveError, 'Cannot remove the last remaining admin');
      // The pre-failure result is left in place, not wiped out or advanced
      // to the rejected role.
      expect(controller.result!.role, 'customer');
    });
  });

  group('clear', () {
    test('resets result and hasSearched', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(
          accountsByEmail: {'amal@example.com': merchant},
        ),
      );
      await controller.lookup('amal@example.com');

      controller.clear();

      expect(controller.result, isNull);
      expect(controller.hasSearched, isFalse);
    });
  });
}
