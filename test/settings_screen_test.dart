import 'dart:convert';

import 'package:chowflow/app/app_routes.dart';
import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:chowflow/features/legal/presentation/privacy_policy_screen.dart';
import 'package:chowflow/features/legal/presentation/terms_of_service_screen.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/settings/data/notification_preferences_repository.dart';
import 'package:chowflow/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_push_notification_gateway.dart';
import 'helpers/memory_notification_preferences_storage.dart';

// See test/login_screen_test.dart and test/auth_service_test.dart for why
// the implicit flow + a mocked http client are used here: no platform
// channel or network access is needed to establish a session this way.
const _testAuthOptions = AuthClientOptions(
  authFlowType: AuthFlowType.implicit,
  autoRefreshToken: false,
);

Map<String, dynamic> _sessionJson({
  required String userId,
  required String email,
}) {
  final now = DateTime.now().toIso8601String();
  return {
    'access_token': 'mock-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'mock-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': now,
    },
  };
}

/// A signed-in [AuthService] backed by a mocked Supabase client, so
/// `getCurrentUserId()`/`getCurrentUserEmail()` return real values without
/// any network access.
Future<AuthService> _signedInAuthService({
  required String userId,
  required String email,
}) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    authOptions: _testAuthOptions,
    httpClient: MockClient((request) async {
      return http.Response(
        jsonEncode(_sessionJson(userId: userId, email: email)),
        200,
      );
    }),
  );
  final service = AuthService(client: client);
  await service.signInWithEmailPassword(email, 'a-strong-password');
  return service;
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile, {this.deleteAccountError});

  final CustomerProfile? profile;

  /// When non-null, [deleteAccount] throws this instead of succeeding, so
  /// the failure-path snackbar behavior can be exercised without a real
  /// backend error.
  final Object? deleteAccountError;

  bool deleteAccountCalled = false;

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async => profile;

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async => throw UnimplementedError('not exercised by this test');

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
    if (deleteAccountError != null) {
      throw deleteAccountError!;
    }
  }
}

/// `_confirmDeleteAccount` calls `context.go(AppRoutes.login)` on success
/// (matching `_logout`), which requires a real `GoRouter` ancestor — this
/// wraps `SettingsScreen` with a minimal one instead of a bare `MaterialApp`,
/// matching the harness pattern `edit_profile_screen_test.dart` uses for the
/// same reason.
Widget _pumpableSettingsScreen({
  required AuthService authService,
  required ProfileRepository profileRepository,
}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, _) => SettingsScreen(
          authService: authService,
          profileRepository: profileRepository,
          notificationPreferencesStorage:
              MemoryNotificationPreferencesStorage(),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login destination')),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (_, _) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        builder: (_, _) => const TermsOfServiceScreen(),
      ),
    ],
  );
  return MaterialApp.router(theme: buildAppTheme(), routerConfig: router);
}

void main() {
  testWidgets(
    'shows the signed-in user\'s real email and phone, not placeholders',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-1',
        email: 'amina@zivo.app',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            authService: authService,
            profileRepository: _FakeProfileRepository(
              CustomerProfile(
                id: 'customer-1',
                firstName: 'Amina',
                lastName: 'Noor',
                phone: '+252 61 111 2222',
              ),
            ),
            notificationPreferencesStorage:
                MemoryNotificationPreferencesStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('amina@zivo.app'), findsOneWidget);
      expect(find.text('+252 61 111 2222'), findsOneWidget);
      expect(find.text('user@example.com'), findsNothing);
      expect(find.text('+1 234 567 8900'), findsNothing);
    },
  );

  testWidgets('shows honest fallback text when there is no phone on file', (
    tester,
  ) async {
    final authService = await _signedInAuthService(
      userId: 'customer-2',
      email: 'no-phone@zivo.app',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SettingsScreen(
          authService: authService,
          profileRepository: _FakeProfileRepository(
            CustomerProfile(
              id: 'customer-2',
              firstName: 'Sam',
              lastName: '',
              phone: '',
            ),
          ),
          notificationPreferencesStorage:
              MemoryNotificationPreferencesStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not added yet'), findsOneWidget);
  });

  testWidgets(
    'dead nav rows (Language/Currency/Theme) are honest placeholders with '
    'no chevron and no tap action',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-3',
        email: 'user3@zivo.app',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            authService: authService,
            profileRepository: _FakeProfileRepository(
              CustomerProfile(
                id: 'customer-3',
                firstName: 'Sam',
                lastName: 'Yusuf',
                phone: '+252 61 000 0000',
              ),
            ),
            notificationPreferencesStorage:
                MemoryNotificationPreferencesStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only Language/Currency/Theme remain unimplemented placeholders —
      // Privacy Policy and Terms & Conditions now navigate to real screens
      // (issue #37).
      expect(find.text('Coming soon'), findsNWidgets(3));
      // The real destinations (Phone Number, Change Password, About Us,
      // Privacy Policy, Terms & Conditions) should render the "this row
      // navigates" chevron.
      expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(5));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Privacy Policy navigates to a screen that renders real policy text',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-9',
        email: 'user9@zivo.app',
      );

      await tester.pumpWidget(
        _pumpableSettingsScreen(
          authService: authService,
          profileRepository: _FakeProfileRepository(
            const CustomerProfile(
              id: 'customer-9',
              firstName: 'Sam',
              lastName: 'Yusuf',
              phone: '+252 61 000 0000',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Privacy Policy'), 200);
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Information We Collect'), findsOneWidget);
      expect(
        find.textContaining('Effective September 14, 2026'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Terms & Conditions navigates to a screen that renders real terms text',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-10',
        email: 'user10@zivo.app',
      );

      await tester.pumpWidget(
        _pumpableSettingsScreen(
          authService: authService,
          profileRepository: _FakeProfileRepository(
            const CustomerProfile(
              id: 'customer-10',
              firstName: 'Sam',
              lastName: 'Yusuf',
              phone: '+252 61 000 0000',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Terms & Conditions'), 200);
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Your Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('About Us opens a static info sheet instead of doing nothing', (
    tester,
  ) async {
    final authService = await _signedInAuthService(
      userId: 'customer-4',
      email: 'user4@zivo.app',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SettingsScreen(
          authService: authService,
          profileRepository: _FakeProfileRepository(
            CustomerProfile(
              id: 'customer-4',
              firstName: 'Sam',
              lastName: 'Yusuf',
              phone: '+252 61 000 0000',
            ),
          ),
          notificationPreferencesStorage:
              MemoryNotificationPreferencesStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('About Us'), 200);
    await tester.tap(find.text('About Us'));
    await tester.pumpAndSettle();

    expect(find.text('Zivo'), findsOneWidget);
    expect(find.textContaining('Version'), findsOneWidget);
  });

  testWidgets(
    'a toggled notification preference persists and is restored the next '
    'time the screen loads',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-5',
        email: 'user5@zivo.app',
      );
      final storage = MemoryNotificationPreferencesStorage();
      final profile = _FakeProfileRepository(
        CustomerProfile(
          id: 'customer-5',
          firstName: 'Sam',
          lastName: 'Yusuf',
          phone: '+252 61 000 0000',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            authService: authService,
            profileRepository: profile,
            notificationPreferencesStorage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Email Notifications" starts off (false, see the previous
      // hardcoded default it replaces). Locate its Switch via the
      // ancestor Row built by ToggleCard.
      final toggleFinder = find.ancestor(
        of: find.text('Email Notifications'),
        matching: find.byType(Row),
      );
      final switchFinder = find.descendant(
        of: toggleFinder.first,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      final saved = await storage.read('customer-5');
      expect(saved.emailNotifications, isTrue);

      // Simulate re-opening the screen: a brand new widget instance reading
      // from the same storage should restore the persisted value instead of
      // resetting to the hardcoded default.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            authService: authService,
            profileRepository: profile,
            notificationPreferencesStorage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reopenedSwitchFinder = find.descendant(
        of: find
            .ancestor(
              of: find.text('Email Notifications'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(reopenedSwitchFinder).value, isTrue);
    },
  );

  testWidgets(
    'turning push notifications on requests permission and persists it once '
    'granted',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-11',
        email: 'user11@zivo.app',
      );
      final storage = MemoryNotificationPreferencesStorage();
      await storage.write(
        'customer-11',
        NotificationPreferences.defaults.copyWith(pushNotifications: false),
      );
      final gateway = FakePushNotificationGateway(granted: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            authService: authService,
            profileRepository: _FakeProfileRepository(
              const CustomerProfile(
                id: 'customer-11',
                firstName: 'Sam',
                lastName: 'Yusuf',
                phone: '+252 61 000 0000',
              ),
            ),
            notificationPreferencesStorage: storage,
            pushNotificationGateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.descendant(
        of: find
            .ancestor(
              of: find.text('Push Notifications'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(gateway.requestPermissionCallCount, 1);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      final saved = await storage.read('customer-11');
      expect(saved.pushNotifications, isTrue);
    },
  );

  testWidgets(
    'turning push notifications on stays off and warns when permission is '
    'denied',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-12',
        email: 'user12@zivo.app',
      );
      final storage = MemoryNotificationPreferencesStorage();
      await storage.write(
        'customer-12',
        NotificationPreferences.defaults.copyWith(pushNotifications: false),
      );
      final gateway = FakePushNotificationGateway(granted: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            authService: authService,
            profileRepository: _FakeProfileRepository(
              const CustomerProfile(
                id: 'customer-12',
                firstName: 'Sam',
                lastName: 'Yusuf',
                phone: '+252 61 000 0000',
              ),
            ),
            notificationPreferencesStorage: storage,
            pushNotificationGateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.descendant(
        of: find
            .ancestor(
              of: find.text('Push Notifications'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      final saved = await storage.read('customer-12');
      expect(saved.pushNotifications, isFalse);
      expect(
        find.textContaining('Enable them in your device settings'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a stored push-on preference is reconciled to off if OS permission was '
    'since revoked',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-13',
        email: 'user13@zivo.app',
      );
      final storage = MemoryNotificationPreferencesStorage();
      await storage.write(
        'customer-13',
        NotificationPreferences.defaults.copyWith(pushNotifications: true),
      );
      final gateway = FakePushNotificationGateway(granted: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            authService: authService,
            profileRepository: _FakeProfileRepository(
              const CustomerProfile(
                id: 'customer-13',
                firstName: 'Sam',
                lastName: 'Yusuf',
                phone: '+252 61 000 0000',
              ),
            ),
            notificationPreferencesStorage: storage,
            pushNotificationGateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.descendant(
        of: find
            .ancestor(
              of: find.text('Push Notifications'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      final saved = await storage.read('customer-13');
      expect(saved.pushNotifications, isFalse);
    },
  );

  testWidgets(
    'canceling the delete-account confirmation dialog does not delete the '
    'account',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-6',
        email: 'user6@zivo.app',
      );
      final repository = _FakeProfileRepository(
        const CustomerProfile(
          id: 'customer-6',
          firstName: 'Sam',
          lastName: 'Yusuf',
          phone: '+252 61 000 0000',
        ),
      );

      await tester.pumpWidget(
        _pumpableSettingsScreen(
          authService: authService,
          profileRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Delete Account'), 200);
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deleteAccountCalled, isFalse);
      expect(find.text('Login destination'), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'confirming account deletion calls the repository, signs out, and '
    'routes to login',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-7',
        email: 'user7@zivo.app',
      );
      final repository = _FakeProfileRepository(
        const CustomerProfile(
          id: 'customer-7',
          firstName: 'Sam',
          lastName: 'Yusuf',
          phone: '+252 61 000 0000',
        ),
      );

      await tester.pumpWidget(
        _pumpableSettingsScreen(
          authService: authService,
          profileRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Delete Account'), 200);
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Two "Delete Account" texts now exist: the settings-screen button
      // (scrolled off-screen but still in the tree) and the dialog's
      // confirm button. `findsAtLeastNWidgets` avoids asserting exactly how
      // many, only that the dialog's copy tap resolves.
      await tester.tap(find.text('Delete Account').last);
      await tester.pumpAndSettle();

      expect(repository.deleteAccountCalled, isTrue);
      expect(authService.getCurrentUserId(), isNull);
      expect(find.text('Login destination'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed account deletion shows an error and leaves the user signed in',
    (tester) async {
      final authService = await _signedInAuthService(
        userId: 'customer-8',
        email: 'user8@zivo.app',
      );
      final repository = _FakeProfileRepository(
        const CustomerProfile(
          id: 'customer-8',
          firstName: 'Sam',
          lastName: 'Yusuf',
          phone: '+252 61 000 0000',
        ),
        deleteAccountError: StateError('boom'),
      );

      await tester.pumpWidget(
        _pumpableSettingsScreen(
          authService: authService,
          profileRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Delete Account'), 200);
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Account').last);
      await tester.pumpAndSettle();

      expect(repository.deleteAccountCalled, isTrue);
      expect(find.textContaining('Could not delete account'), findsOneWidget);
      expect(authService.getCurrentUserId(), isNotNull);
      expect(find.text('Login destination'), findsNothing);
    },
  );
}
