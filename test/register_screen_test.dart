import 'dart:convert';

import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:chowflow/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// See test/login_screen_test.dart for why the injected client opts into the
// implicit auth flow with auto-refresh disabled.
const _testAuthOptions = AuthClientOptions(
  authFlowType: AuthFlowType.implicit,
  autoRefreshToken: false,
);

AuthService _testAuthService() => AuthService(
  client: SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    authOptions: _testAuthOptions,
  ),
);

/// Builds an [AuthService] whose signup calls are answered by [mockClient]
/// instead of hitting the network, so requests can be inspected. Same
/// success-body shape as `test/auth_service_test.dart`'s `_sessionJson`.
AuthService _capturingAuthService(MockClient mockClient) => AuthService(
  client: SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    authOptions: _testAuthOptions,
    httpClient: mockClient,
  ),
);

http.Response _signUpSessionResponse() {
  final now = DateTime.now().toIso8601String();
  return http.Response(
    jsonEncode({
      'access_token': 'mock-access-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'mock-refresh-token',
      'user': {
        'id': 'new-user-id',
        'aud': 'authenticated',
        'email': 'new@example.com',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': now,
      },
    }),
    200,
  );
}

/// Fills every field except the ones named in [skip], opening the date
/// picker and accepting its default date unless `'dob'` is skipped.
Future<void> _fillForm(
  WidgetTester tester, {
  Set<String> skip = const {},
  String phone = '+1 555 123 4567',
}) async {
  if (!skip.contains('firstName')) {
    await tester.enterText(
      find.widgetWithText(TextField, 'First name').first,
      'Jane',
    );
  }
  if (!skip.contains('lastName')) {
    await tester.enterText(
      find.widgetWithText(TextField, 'Last name').first,
      'Doe',
    );
  }
  if (!skip.contains('phone')) {
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number').first,
      phone,
    );
  }
  if (!skip.contains('dob')) {
    final dobField = find.widgetWithText(TextField, 'Date of birth').first;
    await tester.ensureVisible(dobField);
    await tester.tap(dobField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }
  if (!skip.contains('email')) {
    await tester.enterText(
      find.widgetWithText(TextField, 'Email address').first,
      'jane@example.com',
    );
  }
  if (!skip.contains('password')) {
    await tester.enterText(
      find.widgetWithText(TextField, 'Password').first,
      'a-strong-password',
    );
  }
  if (!skip.contains('confirmPassword')) {
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password').first,
      'a-strong-password',
    );
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Create account'));
  await tester.tap(find.text('Create account'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the sign-up form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RegisterScreen(authService: _testAuthService()),
      ),
    );
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow at 320x640 with a 1.4x text scale', (
    tester,
  ) async {
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
          child: RegisterScreen(authService: _testAuthService()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    // The "Already have an account? / Sign in" row is the longest line of
    // text on either auth screen and was the first thing to overflow at
    // this size/scale before the Row -> Wrap fix.
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('validation', () {
    testWidgets('blocks submission when first name is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: RegisterScreen(authService: _testAuthService()),
        ),
      );
      await tester.pump();

      await _fillForm(tester, skip: {'firstName'});
      await _submit(tester);

      expect(find.text('Please fill in every field.'), findsOneWidget);
    });

    testWidgets('blocks submission when last name is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: RegisterScreen(authService: _testAuthService()),
        ),
      );
      await tester.pump();

      await _fillForm(tester, skip: {'lastName'});
      await _submit(tester);

      expect(find.text('Please fill in every field.'), findsOneWidget);
    });

    testWidgets('blocks submission when phone is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: RegisterScreen(authService: _testAuthService()),
        ),
      );
      await tester.pump();

      await _fillForm(tester, skip: {'phone'});
      await _submit(tester);

      expect(find.text('Please fill in every field.'), findsOneWidget);
    });

    testWidgets('blocks submission when date of birth is not selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: RegisterScreen(authService: _testAuthService()),
        ),
      );
      await tester.pump();

      await _fillForm(tester, skip: {'dob'});
      await _submit(tester);

      expect(find.text('Please fill in every field.'), findsOneWidget);
    });

    testWidgets(
      'blocks submission with a validation message for an invalid phone '
      'number',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: RegisterScreen(authService: _testAuthService()),
          ),
        );
        await tester.pump();

        await _fillForm(tester, phone: 'not-a-number');
        await _submit(tester);

        expect(find.text('Please enter a valid phone number.'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'valid input calls signUpWithEmailPassword with the trimmed field '
    'values',
    (tester) async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return _signUpSessionResponse();
      });
      final now = DateTime.now();
      final expectedDob = DateTime(now.year - 18, now.month, now.day);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: RegisterScreen(authService: _capturingAuthService(mockClient)),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'First name').first,
        ' Jane ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Last name').first,
        ' Doe ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone number').first,
        ' +1 555 123 4567 ',
      );
      final dobField = find.widgetWithText(TextField, 'Date of birth').first;
      await tester.ensureVisible(dobField);
      await tester.tap(dobField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Email address').first,
        ' jane@example.com ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password').first,
        'a-strong-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password').first,
        'a-strong-password',
      );
      await _submit(tester);

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/auth/v1/signup');
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['email'], 'jane@example.com');
      expect(body['password'], 'a-strong-password');
      final data = body['data'] as Map<String, dynamic>;
      expect(data['firstname'], 'Jane');
      expect(data['lastname'], 'Doe');
      expect(data['phone'], '+1 555 123 4567');
      expect(data['dob'], DateFormat('yyyy-MM-dd').format(expectedDob));
    },
  );
}
