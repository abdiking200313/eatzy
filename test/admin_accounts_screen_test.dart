import 'package:chowflow/features/merchant/admin/data/admin_accounts_repository.dart';
import 'package:chowflow/features/merchant/admin/models/admin_account.dart';
import 'package:chowflow/features/merchant/admin/presentation/admin_accounts_controller.dart';
import 'package:chowflow/features/merchant/admin/presentation/admin_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

// Widget-tests the admin-only "Accounts" list (requested directly by the app
// owner, 2026-09-18), against the fake repository rather than a live
// Supabase project (no network access in this sandbox).
void main() {
  const me = AdminAccount(
    id: 'admin-1',
    firstName: 'Owner',
    lastName: 'Admin',
    email: 'owner@example.com',
    role: 'admin',
  );
  const amal = AdminAccount(
    id: 'profile-1',
    firstName: 'Amal',
    lastName: 'Hassan',
    email: 'amal@example.com',
    role: 'customer',
  );
  const bilal = AdminAccount(
    id: 'profile-2',
    firstName: 'Bilal',
    lastName: 'Noor',
    email: 'bilal@example.com',
    role: 'merchant',
  );

  Future<AdminAccountsController> pumpScreen(
    WidgetTester tester, {
    List<AdminAccount> accounts = const [me, amal, bilal],
    FakeAdminAccountsRepository? repository,
  }) async {
    final controller = AdminAccountsController(
      repository: repository ?? FakeAdminAccountsRepository(accounts: accounts),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminAccountsScreen(
            controller: controller,
            currentUserId: me.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> pickRole(WidgetTester tester, String id, String label) async {
    await tester.tap(find.byKey(ValueKey('role-$id')));
    await tester.pumpAndSettle();
    // The open menu repeats the current label; the last match is the menu
    // entry that sits on top.
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('lists every account with its name, email and role', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Amal Hassan'), findsOneWidget);
    expect(find.text('amal@example.com'), findsOneWidget);
    expect(find.text('Bilal Noor'), findsOneWidget);
    expect(find.text('bilal@example.com'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Merchant'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets("disables the signed-in admin's own dropdown", (tester) async {
    await pumpScreen(tester);

    expect(find.text('You'), findsOneWidget);
    final own = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('role-admin-1')),
    );
    final other = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('role-profile-1')),
    );
    expect(own.onChanged, isNull);
    expect(other.onChanged, isNotNull);
  });

  testWidgets('shows an empty state when there are no accounts', (
    tester,
  ) async {
    await pumpScreen(tester, accounts: const []);

    expect(find.text('No accounts yet.'), findsOneWidget);
  });

  testWidgets('shows the server error with a retry that reloads', (
    tester,
  ) async {
    final repository = FakeAdminAccountsRepository(accounts: const [amal])
      ..failureToThrow = const AdminAccountsException(
        'Admin privileges required',
      );
    await pumpScreen(tester, repository: repository);

    expect(find.text('Admin privileges required'), findsOneWidget);

    repository.failureToThrow = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Amal Hassan'), findsOneWidget);
  });

  testWidgets('typing in the search box filters after a short debounce', (
    tester,
  ) async {
    final repository = FakeAdminAccountsRepository(
      accounts: const [me, amal, bilal],
    );
    await pumpScreen(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'bilal');
    // Not yet: the search waits for the admin to stop typing.
    expect(repository.searches, ['']);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.searches.last, 'bilal');
    expect(find.text('Bilal Noor'), findsOneWidget);
    expect(find.text('Amal Hassan'), findsNothing);
  });

  testWidgets('shows a no-match message for a search with no results', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No accounts match "zzz".'), findsOneWidget);
  });

  testWidgets('"Load more" appends the next page', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final many = [
      for (var i = 0; i < AdminAccountsController.pageSize + 2; i++)
        AdminAccount(
          id: 'p$i',
          firstName: 'Person',
          lastName: '$i',
          email: 'person$i@example.com',
          role: 'customer',
        ),
    ];
    await pumpScreen(tester, accounts: many);

    expect(find.text('Person 24'), findsOneWidget);
    expect(find.text('Person 25'), findsNothing);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Person 25'), findsOneWidget);
    expect(find.text('Person 26'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('confirming a role change saves it and shows a snackbar', (
    tester,
  ) async {
    final controller = await pumpScreen(tester);

    await pickRole(tester, 'profile-1', 'Merchant');

    // Confirmation dialog appears before anything is changed.
    expect(find.text("Change Amal Hassan's role?"), findsOneWidget);
    expect(controller.accounts[1].role, 'customer');

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(controller.accounts[1].role, 'merchant');
    expect(find.text('Amal Hassan is now merchant.'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation leaves the role unchanged', (
    tester,
  ) async {
    final controller = await pumpScreen(tester);

    await pickRole(tester, 'profile-1', 'Admin');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.accounts[1].role, 'customer');
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('role-profile-1')),
    );
    expect(dropdown.value, 'customer');
  });

  testWidgets('a rejected role change shows the server message', (
    tester,
  ) async {
    final repository = FakeAdminAccountsRepository(
      accounts: const [me, amal, bilal],
    );
    final controller = await pumpScreen(tester, repository: repository);
    repository.failureToThrow = const AdminAccountsException(
      'Admin privileges required',
    );

    await pickRole(tester, 'profile-1', 'Merchant');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Admin privileges required'), findsOneWidget);
    expect(controller.accounts[1].role, 'customer');
  });
}
