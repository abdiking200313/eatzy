import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/profile/presentation/profile_screen.dart';
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

    expect(find.text('Gold Member'), findsNothing);
    expect(find.text('Activity'), findsNothing);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Completed'), findsNothing);
    expect(find.text('Cancelled'), findsNothing);
    expect(find.byIcon(Icons.verified), findsNothing);
  });
}

class _ProfileRepository implements ProfileRepository {
  const _ProfileRepository(this.profile);

  final CustomerProfile? profile;

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async => profile;
}
