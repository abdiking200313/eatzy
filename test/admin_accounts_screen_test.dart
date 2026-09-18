import 'package:chowflow/features/merchant/admin/models/admin_account_lookup.dart';
import 'package:chowflow/features/merchant/admin/presentation/admin_accounts_controller.dart';
import 'package:chowflow/features/merchant/admin/presentation/admin_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_merchant_repositories.dart';

// Widget-tests the admin-only "promote an account" screen (requested
// directly by the app owner, 2026-09-18), against the fake repository
// rather than a live Supabase project (no network access in this sandbox).
void main() {
  const customer = AdminAccountLookup(
    id: 'profile-1',
    firstName: 'Amal',
    lastName: 'Hassan',
    role: 'customer',
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    AdminAccountsController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminAccountsScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a validation error for an empty email', (tester) async {
    final controller = AdminAccountsController(
      repository: FakeAdminAccountsRepository(),
    );
    await pumpScreen(tester, controller);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an email address.'), findsOneWidget);
  });

  testWidgets('shows "no account found" for an unmatched email', (
    tester,
  ) async {
    final controller = AdminAccountsController(
      repository: FakeAdminAccountsRepository(),
    );
    await pumpScreen(tester, controller);

    await tester.enterText(find.byType(TextFormField), 'nobody@example.com');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('No account found for that email.'), findsOneWidget);
  });

  testWidgets('finds a matching account and shows its current role', (
    tester,
  ) async {
    final controller = AdminAccountsController(
      repository: FakeAdminAccountsRepository(
        accountsByEmail: {'amal@example.com': customer},
      ),
    );
    await pumpScreen(tester, controller);

    await tester.enterText(find.byType(TextFormField), 'amal@example.com');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Amal Hassan'), findsOneWidget);
    expect(find.text('Current role: customer'), findsOneWidget);
    // No change selected yet -- the apply button starts disabled.
    final applyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply role change'),
    );
    expect(applyButton.onPressed, isNull);
  });

  testWidgets('confirming a role change applies it and shows a snackbar', (
    tester,
  ) async {
    final controller = AdminAccountsController(
      repository: FakeAdminAccountsRepository(
        accountsByEmail: {'amal@example.com': customer},
      ),
    );
    await pumpScreen(tester, controller);

    await tester.enterText(find.byType(TextFormField), 'amal@example.com');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Merchant'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply role change'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears before anything is changed.
    expect(find.text("Change Amal Hassan's role?"), findsOneWidget);
    expect(controller.result!.role, 'customer');

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(controller.result!.role, 'merchant');
    expect(find.text('Amal Hassan is now merchant.'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation leaves the role unchanged', (
    tester,
  ) async {
    final controller = AdminAccountsController(
      repository: FakeAdminAccountsRepository(
        accountsByEmail: {'amal@example.com': customer},
      ),
    );
    await pumpScreen(tester, controller);

    await tester.enterText(find.byType(TextFormField), 'amal@example.com');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply role change'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.result!.role, 'customer');
  });
}
