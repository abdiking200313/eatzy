import 'package:chowflow/config/theme.dart';
import 'package:chowflow/features/legal/presentation/legal_document_screen.dart';
import 'package:chowflow/features/legal/presentation/privacy_policy_screen.dart';
import 'package:chowflow/features/legal/presentation/terms_of_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Smoke tests for the two static legal screens added by issue #37 (the app
// previously had no privacy policy or terms of service at all — only dead
// "Coming soon" rows on Settings). These confirm each screen renders its
// drafted content without throwing; navigation from Settings into these
// screens is covered separately by test/settings_screen_test.dart.
void main() {
  testWidgets('PrivacyPolicyScreen renders its title and every section '
      'heading without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const PrivacyPolicyScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.textContaining('Effective September 14, 2026'), findsOneWidget);
    for (final section in PrivacyPolicyScreen.document.sections) {
      expect(
        find.text(section.heading),
        findsOneWidget,
        reason: 'missing section: ${section.heading}',
      );
    }
    // The two third-party hosts issue #37 called out must actually be named
    // in the policy text, not just implied.
    expect(find.textContaining('fonts.gstatic.com'), findsOneWidget);
    expect(find.textContaining('lh3.googleusercontent.com'), findsOneWidget);
    // The account-deletion path (issue #36) must be referenced honestly.
    expect(find.textContaining('Delete Account'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('TermsOfServiceScreen renders its title and every section '
      'heading without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const TermsOfServiceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms & Conditions'), findsWidgets);
    for (final section in TermsOfServiceScreen.document.sections) {
      expect(
        find.text(section.heading),
        findsOneWidget,
        reason: 'missing section: ${section.heading}',
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'LegalDocumentScreen renders an arbitrary document (reusability check)',
    (tester) async {
      const document = LegalDocument(
        title: 'Sample Document',
        effectiveDate: 'January 1, 2030',
        intro: 'An intro paragraph.',
        sections: [
          LegalSection(heading: 'Heading One', body: 'Body one.'),
          LegalSection(heading: 'Heading Two', body: 'Body two.'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const LegalDocumentScreen(document: document),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sample Document'), findsWidgets);
      expect(find.textContaining('January 1, 2030'), findsOneWidget);
      expect(find.text('An intro paragraph.'), findsOneWidget);
      expect(find.text('Heading One'), findsOneWidget);
      expect(find.text('Body two.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
