// Redesign phase 6/7 (#27): 320x640 @1.4 text-scale no-overflow coverage
// for every orders/activity/account-area screen touched in this phase, per
// the #21 per-screen DoD template.
import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/orders/presentation/track_order_screen.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/profile/presentation/profile_screen.dart';
import 'package:chowflow/features/rewards/presentation/rewards_profile_screen.dart';
import 'package:chowflow/features/rewards/presentation/rewards_screen.dart';
import 'package:chowflow/features/settings/presentation/settings_screen.dart';
import 'package:chowflow/features/support/presentation/support_screen.dart';
import 'package:chowflow/features/wallet/data/wallet_repository.dart';
import 'package:chowflow/features/wallet/models/wallet_payment_method_record.dart';
import 'package:chowflow/features/wallet/models/wallet_transaction_record.dart';
import 'package:chowflow/features/wallet/presentation/wallet_screen.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/activity/presentation/activity_screen.dart';
import 'package:chowflow/screens/addresses.dart';
import 'package:chowflow/screens/payment_methods.dart';
import 'package:chowflow/widgets/app_misc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpNarrow(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: screen,
        ),
      ),
    );
    await tester.pump();
  }

  ActivityController activityWithSampleItems() {
    return ActivityController()
      ..record(
        ActivityItem(
          id: 'food-1',
          serviceId: ServiceId.food,
          title: 'Jollof Feast Order',
          subtitle: 'Order #45782',
          status: 'On the way',
          occurredAt: DateTime.utc(2026, 8, 1),
          amount: 18.5,
          detailsRoute: '',
        ),
      )
      ..record(
        ActivityItem(
          id: 'grocery-1',
          serviceId: ServiceId.grocery,
          title: 'Bakaara groceries',
          status: 'Delivered',
          occurredAt: DateTime.utc(2026, 7, 27),
          amount: 24,
          detailsRoute: '',
        ),
      );
  }

  group('320x640 @1.4x text-scale stays overflow-free', () {
    testWidgets('Activity tab renders status pills, not bare text', (
      tester,
    ) async {
      await pumpNarrow(
        tester,
        ActivityScreen(controller: activityWithSampleItems()),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('On the way'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.text('On the way'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Track order', (tester) async {
      await pumpNarrow(
        tester,
        const ZivoServiceTheme(
          serviceId: ServiceId.food,
          child: TrackOrderScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Addresses', (tester) async {
      await pumpNarrow(tester, const AddressesScreen());

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusPill), findsWidgets);
    });

    testWidgets('Payment methods', (tester) async {
      await pumpNarrow(tester, const PaymentMethodsScreen());

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusPill), findsWidgets);
    });

    testWidgets('Profile', (tester) async {
      await pumpNarrow(
        tester,
        ProfileScreen(
          profileRepository: const _FakeProfileRepository(
            CustomerProfile(
              id: 'customer-1',
              firstName: 'Amina',
              lastName: 'Noor',
              phone: '+252 61 234 5678',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings', (tester) async {
      await pumpNarrow(tester, const SettingsScreen());

      expect(tester.takeException(), isNull);
    });

    testWidgets('Wallet', (tester) async {
      await pumpNarrow(
        tester,
        WalletScreen(walletRepository: _FakeWalletRepository()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusPill), findsWidgets);
    });

    testWidgets('Rewards', (tester) async {
      await pumpNarrow(tester, const RewardsScreen());

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusPill), findsWidgets);
    });

    testWidgets('Rewards profile', (tester) async {
      await pumpNarrow(tester, const RewardsProfileScreen());

      expect(tester.takeException(), isNull);
    });

    testWidgets('Support', (tester) async {
      await pumpNarrow(tester, const SupportScreen());

      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository(this.profile);

  final CustomerProfile? profile;

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async => profile;
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<double> fetchBalance() async => 120.5;

  @override
  Future<List<WalletTransactionRecord>> fetchTransactions({
    int limit = 20,
  }) async => [
    WalletTransactionRecord(
      id: 'txn-1',
      type: WalletTransactionType.orderPayment,
      amount: -18.5,
      description: 'Jollof Feast Order',
      createdAt: DateTime.utc(2026, 8, 1),
      orderId: '45782',
    ),
  ];

  @override
  Future<List<WalletPaymentMethodRecord>> fetchPaymentMethods() async => const [
    WalletPaymentMethodRecord(
      id: 'pm-1',
      brand: 'Visa Card',
      lastFour: '4829',
      isDefault: true,
    ),
  ];
}
