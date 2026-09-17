import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/auth/data/merchant_auth_service.dart';
import 'package:merchant_app/features/auth/presentation/sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _merchantUser = User(
  id: 'merchant-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

/// A fake [MerchantAuthService] that never touches a real Supabase client,
/// so these widget tests exercise [SignInScreen]'s handling of each
/// outcome without any network access.
class _FakeMerchantAuthService implements MerchantAuthService {
  _FakeMerchantAuthService(this._result);

  /// What `signInWithEmailPassword` should do: return a user, or throw.
  final Object _result;

  @override
  Future<User> signInWithEmailPassword(String email, String password) async {
    final result = _result;
    if (result is Exception) throw result;
    return result as User;
  }

  @override
  Future<User?> restoreSessionIfAuthorized() async => null;

  @override
  Future<void> signOut() async {}

  @override
  User? get currentUser => null;
}

void main() {
  Future<void> pumpSignIn(
    WidgetTester tester,
    MerchantAuthService service, {
    required ValueChanged<User> onSignedIn,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SignInScreen(onSignedIn: onSignedIn, authService: service),
      ),
    );
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).first,
      'owner@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('a merchant account reaches onSignedIn', (tester) async {
    User? signedInUser;
    await pumpSignIn(
      tester,
      _FakeMerchantAuthService(_merchantUser),
      onSignedIn: (user) => signedInUser = user,
    );

    await fillAndSubmit(tester);

    expect(signedInUser, _merchantUser);
  });

  testWidgets('a customer account is rejected with an explanatory message', (
    tester,
  ) async {
    User? signedInUser;
    await pumpSignIn(
      tester,
      _FakeMerchantAuthService(const NotAMerchantException('customer')),
      onSignedIn: (user) => signedInUser = user,
    );

    await fillAndSubmit(tester);

    expect(signedInUser, isNull);
    expect(find.textContaining('not a merchant account'), findsOneWidget);
  });

  testWidgets('bad credentials show the auth error message', (tester) async {
    User? signedInUser;
    await pumpSignIn(
      tester,
      _FakeMerchantAuthService(
        const AuthException('Invalid login credentials'),
      ),
      onSignedIn: (user) => signedInUser = user,
    );

    await fillAndSubmit(tester);

    expect(signedInUser, isNull);
    expect(find.text('Invalid login credentials'), findsOneWidget);
  });
}
