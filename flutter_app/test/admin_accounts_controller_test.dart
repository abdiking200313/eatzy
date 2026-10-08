import 'package:chowflow/features/merchant/admin/data/admin_accounts_repository.dart';
import 'package:chowflow/features/merchant/admin/models/admin_account.dart';
import 'package:chowflow/features/merchant/admin/presentation/admin_accounts_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

// Unit-tests `AdminAccountsController`'s list/search/paging/role-change
// bookkeeping (requested directly by the app owner, 2026-09-18), against the
// fake repository rather than a live Supabase project (no network access in
// this sandbox).
void main() {
  AdminAccount account(int i, {String role = 'customer'}) => AdminAccount(
    id: 'profile-$i',
    firstName: 'User',
    lastName: '$i',
    email: 'user$i@example.com',
    role: role,
  );

  List<AdminAccount> accounts(int count) => [
    for (var i = 1; i <= count; i++) account(i),
  ];

  group('load', () {
    test('loads the first page and reports no more when it all fits', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(accounts: accounts(3)),
      );

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.loadError, isNull);
      expect(controller.accounts.map((a) => a.id), [
        'profile-1',
        'profile-2',
        'profile-3',
      ]);
      expect(controller.hasMore, isFalse);
    });

    test('caps the first page at pageSize and reports more', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(
          accounts: accounts(AdminAccountsController.pageSize + 1),
        ),
      );

      await controller.load();

      expect(controller.accounts, hasLength(AdminAccountsController.pageSize));
      expect(controller.hasMore, isTrue);
    });

    test('an exactly-full last page reports no more', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(
          accounts: accounts(AdminAccountsController.pageSize),
        ),
      );

      await controller.load();

      expect(controller.accounts, hasLength(AdminAccountsController.pageSize));
      expect(controller.hasMore, isFalse);
    });

    test('filters by the trimmed search text', () async {
      final repository = FakeAdminAccountsRepository(accounts: accounts(12));
      final controller = AdminAccountsController(repository: repository);

      await controller.load('  USER11 ');

      expect(controller.query, 'USER11');
      expect(repository.searches.last, 'USER11');
      expect(controller.accounts.map((a) => a.id), ['profile-11']);
    });

    test('sets loadError and clears accounts on failure', () async {
      final repository = FakeAdminAccountsRepository(accounts: accounts(2));
      final controller = AdminAccountsController(repository: repository);
      await controller.load();

      repository.failureToThrow = const AdminAccountsException(
        'Admin privileges required',
      );
      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.loadError, 'Admin privileges required');
      expect(controller.accounts, isEmpty);
    });

    test('uses a generic message for unexpected errors', () async {
      final repository = FakeAdminAccountsRepository(accounts: accounts(1))
        ..failureToThrow = Exception('network down');
      final controller = AdminAccountsController(repository: repository);

      await controller.load();

      expect(controller.loadError, isNotNull);
      expect(controller.loadError, isNot(contains('network down')));
    });
  });

  group('loadMore', () {
    test('appends the next page using the loaded count as offset', () async {
      const total = AdminAccountsController.pageSize + 5;
      final repository = FakeAdminAccountsRepository(accounts: accounts(total));
      final controller = AdminAccountsController(repository: repository);
      await controller.load();

      await controller.loadMore();

      expect(repository.offsets, [0, AdminAccountsController.pageSize]);
      expect(controller.accounts, hasLength(total));
      expect(controller.accounts.last.id, 'profile-$total');
      expect(controller.hasMore, isFalse);
    });

    test('is a no-op when there is nothing more to load', () async {
      final repository = FakeAdminAccountsRepository(accounts: accounts(2));
      final controller = AdminAccountsController(repository: repository);
      await controller.load();

      await controller.loadMore();

      expect(repository.offsets, [0]);
    });

    test(
      'a failure keeps the loaded accounts and sets loadMoreError',
      () async {
        final repository = FakeAdminAccountsRepository(
          accounts: accounts(AdminAccountsController.pageSize + 1),
        );
        final controller = AdminAccountsController(repository: repository);
        await controller.load();

        repository.failureToThrow = Exception('network down');
        await controller.loadMore();

        expect(
          controller.accounts,
          hasLength(AdminAccountsController.pageSize),
        );
        expect(controller.loadMoreError, isNotNull);
        expect(controller.loadError, isNull);
        expect(controller.isLoadingMore, isFalse);
        expect(controller.hasMore, isTrue);
      },
    );
  });

  group('setRole', () {
    test('returns false for an account that is not loaded', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(accounts: accounts(1)),
      );
      await controller.load();

      expect(await controller.setRole('nobody', 'merchant'), isFalse);
    });

    test('updates the loaded account on success', () async {
      final controller = AdminAccountsController(
        repository: FakeAdminAccountsRepository(accounts: accounts(2)),
      );
      await controller.load();

      final succeeded = await controller.setRole('profile-2', 'merchant');

      expect(succeeded, isTrue);
      expect(controller.saveError, isNull);
      expect(controller.savingId, isNull);
      expect(controller.accounts[0].role, 'customer');
      expect(controller.accounts[1].role, 'merchant');
    });

    test(
      'marks the account as saving while the request is in flight',
      () async {
        final controller = AdminAccountsController(
          repository: FakeAdminAccountsRepository(accounts: accounts(1)),
        );
        await controller.load();

        final seen = <String?>[];
        controller.addListener(() => seen.add(controller.savingId));
        await controller.setRole('profile-1', 'admin');

        expect(seen.first, 'profile-1');
        expect(controller.savingId, isNull);
      },
    );

    test('a rejection sets saveError and leaves the role unchanged', () async {
      final repository = FakeAdminAccountsRepository(accounts: accounts(1));
      final controller = AdminAccountsController(repository: repository);
      await controller.load();
      repository.failureToThrow = const AdminAccountsException(
        'Cannot remove the last remaining admin',
      );

      final succeeded = await controller.setRole('profile-1', 'admin');

      expect(succeeded, isFalse);
      expect(controller.saveError, 'Cannot remove the last remaining admin');
      expect(controller.savingId, isNull);
      expect(controller.accounts.single.role, 'customer');
    });
  });

  group('AdminAccount', () {
    test('displayName falls back from name to email to id', () {
      const named = AdminAccount(
        id: 'i',
        firstName: 'Amal',
        lastName: 'Hassan',
        email: 'a@example.com',
        role: 'customer',
      );
      const unnamed = AdminAccount(
        id: 'i',
        firstName: '',
        lastName: '',
        email: 'a@example.com',
        role: 'customer',
      );
      const bare = AdminAccount(
        id: 'i',
        firstName: '',
        lastName: '',
        email: '',
        role: 'customer',
      );

      expect(named.displayName, 'Amal Hassan');
      expect(unnamed.displayName, 'a@example.com');
      expect(bare.displayName, 'i');
    });

    test('fromMap tolerates null name and email', () {
      final parsed = AdminAccount.fromMap({
        'id': 'i',
        'firstname': null,
        'lastname': null,
        'email': null,
        'role': 'admin',
      });

      expect(parsed.firstName, '');
      expect(parsed.email, '');
      expect(parsed.role, 'admin');
    });
  });
}
