import 'dart:convert';

import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  const _FakeProfileRepository(this.profile);

  final CustomerProfile? profile;

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async => profile;

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async => throw UnimplementedError('not exercised by this test');
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
            profileRepository: const _FakeProfileRepository(
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
          profileRepository: const _FakeProfileRepository(
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
    'dead nav rows (Language/Currency/Theme/Privacy/Terms) are honest '
    'placeholders with no chevron and no tap action',
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
            profileRepository: const _FakeProfileRepository(
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

      expect(find.text('Coming soon'), findsNWidgets(5));
      // Only the real destinations (Phone Number, Change Password, About
      // Us) should render the "this row navigates" chevron.
      expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(3));

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
          profileRepository: const _FakeProfileRepository(
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
      const profile = _FakeProfileRepository(
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
}
