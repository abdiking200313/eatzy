import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/store/presentation/merchant_store_controller.dart';
import 'package:merchant_app/features/shell/presentation/merchant_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_merchant_repositories.dart';

// Smoke-tests the nav shell: it must land on real routed "My Store"
// (issue #133) / "Orders" (still a stub, issue #134) destinations, and
// switching tabs must actually switch content. "My Store" is given a fake,
// no-store-yet repository so this stays a pure widget test with no Supabase
// network access.
void main() {
  const testUser = User(
    id: 'merchant-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );

  MerchantStoreController fakeStoreController() =>
      MerchantStoreController(repository: FakeMerchantStoreRepository());

  testWidgets('shows "My Store" destination by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantShell(
          user: testUser,
          onSignedOut: () {},
          myStoreController: fakeStoreController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Store'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    // No store yet for this fake merchant -- the empty/create-store state.
    expect(find.text("You don't have a store yet"), findsOneWidget);
  });

  testWidgets('switching to Orders shows the Orders destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantShell(
          user: testUser,
          onSignedOut: () {},
          myStoreController: fakeStoreController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Orders'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Incoming and past orders are coming soon. This is a '
        'placeholder destination for issue #134.',
      ),
      findsOneWidget,
    );
  });
}
