import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/shell/presentation/merchant_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Smoke-tests the minimal nav shell from issue #132: it must land on real
// routed "My Store" / "Orders" destinations (not just TODO comments), and
// switching tabs must actually switch content.
void main() {
  const testUser = User(
    id: 'merchant-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );

  testWidgets('shows "My Store" destination by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantShell(user: testUser, onSignedOut: () {}),
      ),
    );

    expect(find.text('My Store'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    expect(
      find.text(
        'Catalog and store management are coming soon. This is a '
        'placeholder destination for issue #133.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('switching to Orders shows the Orders destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantShell(user: testUser, onSignedOut: () {}),
      ),
    );

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
