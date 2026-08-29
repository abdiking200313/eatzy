import 'package:chowflow/features/checkout/presentation/checkout_screen.dart';
import 'package:chowflow/features/profile/presentation/profile_screen.dart';
import 'package:chowflow/features/rewards/presentation/rewards_screen.dart';
import 'package:chowflow/features/settings/presentation/settings_screen.dart';
import 'package:chowflow/features/support/presentation/support_screen.dart';
import 'package:chowflow/features/wallet/presentation/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('representative moved feature screens render', (tester) async {
    const cases = <({Widget screen, String title})>[
      (screen: CheckoutScreen(), title: 'Checkout'),
      (screen: ProfileScreen(), title: 'Profile'),
      (screen: RewardsScreen(), title: 'Rewards & Achievements'),
      (screen: SettingsScreen(), title: 'Settings'),
      (screen: SupportScreen(), title: 'Help & Support'),
      (screen: WalletScreen(), title: 'My Wallet'),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(MaterialApp(home: testCase.screen));
      await tester.pump();

      expect(
        find.text(testCase.title),
        findsOneWidget,
        reason: '${testCase.screen.runtimeType} should render its title',
      );
    }
  });
}
