import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/profile/presentation/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// [EditProfileScreen] calls `context.pop()` on a successful save (see
/// `_save`), which requires a real `GoRouter` ancestor — this wraps it with
/// a minimal one instead of a bare `MaterialApp`, matching the harness
/// pattern other screen tests use for the same reason (see
/// `cart_screen_test.dart`).
Widget _pumpableEditProfileScreen(ProfileRepository repository) {
  final router = GoRouter(
    initialLocation: '/edit-profile',
    routes: [
      GoRoute(
        path: '/edit-profile',
        builder: (_, _) => EditProfileScreen(profileRepository: repository),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Profile destination')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildAppTheme(), routerConfig: router);
}

void main() {
  testWidgets('pre-fills the form with the current profile', (tester) async {
    await tester.pumpWidget(
      _pumpableEditProfileScreen(
        _FakeProfileRepository(
          const CustomerProfile(
            id: 'customer-1',
            firstName: 'Amina',
            lastName: 'Noor',
            phone: '+252 61 234 5678',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Noor'), findsOneWidget);
    expect(find.text('+252 61 234 5678'), findsOneWidget);
  });

  testWidgets('shows an inline error and skips the write for an empty name', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(
      const CustomerProfile(
        id: 'customer-1',
        firstName: 'Amina',
        lastName: 'Noor',
        phone: '',
      ),
    );
    await tester.pumpWidget(_pumpableEditProfileScreen(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile-first-name')),
      '',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(repository.updateCalls, isEmpty);
  });

  testWidgets('saves valid edits through updateProfile', (tester) async {
    final repository = _FakeProfileRepository(
      const CustomerProfile(
        id: 'customer-1',
        firstName: 'Amina',
        lastName: 'Noor',
        phone: '',
      ),
    );
    await tester.pumpWidget(_pumpableEditProfileScreen(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile-last-name')),
      'Hassan',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, hasLength(1));
    expect(repository.updateCalls.single.lastName, 'Hassan');
    expect(find.text('Profile updated.'), findsOneWidget);
  });
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);

  final CustomerProfile? profile;
  final List<({String firstName, String lastName, String phone})> updateCalls =
      [];

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async => profile;

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    updateCalls.add((firstName: firstName, lastName: lastName, phone: phone));
    return CustomerProfile(
      id: 'customer-1',
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
  }
}
