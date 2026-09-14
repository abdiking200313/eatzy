import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/profile/presentation/profile_screen.dart';
import 'package:chowflow/platform/error_reporting/error_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile shows customer identity without activity statistics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ProfileScreen(
          profileRepository: _ProfileRepository(
            const CustomerProfile(
              id: 'customer-1',
              firstName: 'Amina',
              lastName: 'Noor',
              phone: '+252 61 234 5678',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina Noor'), findsOneWidget);
    expect(find.text('+252 61 234 5678'), findsOneWidget);
    expect(find.text('Addresses'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    expect(find.text('Gold Member'), findsNothing);
    expect(find.text('Activity'), findsNothing);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Completed'), findsNothing);
    expect(find.text('Cancelled'), findsNothing);
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets(
    'a failed profile load still renders the empty state, but reports the '
    'error instead of swallowing it silently (issue #40)',
    (tester) async {
      final originalReporter = ErrorReporting.instance;
      final fakeReporter = _FakeErrorReporter();
      ErrorReporting.instance = fakeReporter;
      addTearDown(() => ErrorReporting.instance = originalReporter);

      final loadError = StateError('profile lookup failed');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ProfileScreen(
            profileRepository: _ThrowingProfileRepository(loadError),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Unchanged UI behavior: a failed load still falls back to the
      // "Zivo customer" empty state rather than getting a different UI.
      expect(find.text('Zivo customer'), findsOneWidget);

      // But the failure must now be visible instead of silently swallowed.
      expect(fakeReporter.reported, hasLength(1));
      expect(fakeReporter.reported.single.error, loadError);
      expect(
        fakeReporter.reported.single.context,
        'ProfileScreen._loadProfile',
      );
    },
  );
}

class _ProfileRepository implements ProfileRepository {
  const _ProfileRepository(this.profile);

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

class _ThrowingProfileRepository implements ProfileRepository {
  const _ThrowingProfileRepository(this.error);

  final Object error;

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async => throw error;

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async => throw error;
}

class _FakeErrorReporter implements ErrorReporter {
  final List<({Object error, StackTrace stack, String? context})> reported = [];

  @override
  void reportError(Object error, StackTrace stack, {String? context}) {
    reported.add((error: error, stack: stack, context: context));
  }
}
