import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:chowflow/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
