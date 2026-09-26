import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';

/// One labeled paragraph (or group of paragraphs) inside a [LegalDocument] —
/// e.g. "Information We Collect" / "Your Rights and Choices".
///
/// [body] may contain blank lines (`\n\n`) to separate multiple paragraphs
/// within the same section; [LegalDocumentScreen] renders it verbatim.
class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

/// The full text of a static legal document (Privacy Policy, Terms of
/// Service, ...), structured so [LegalDocumentScreen] can render any of them
/// the same way instead of each screen hand-rolling its own layout.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.effectiveDate,
    required this.intro,
    required this.sections,
  });

  final String title;

  /// e.g. "September 14, 2026" — shown under the title so a future edit is
  /// visibly dated rather than silently changing settled text.
  final String effectiveDate;

  /// A short paragraph shown before the first numbered section.
  final String intro;
  final List<LegalSection> sections;
}

/// Renders a [LegalDocument] as a scrollable, read-only screen.
///
/// This is a reusable shell (not a Privacy-Policy-specific widget) so the
/// Privacy Policy and Terms of Service screens — and any future legal
/// document — share one layout instead of duplicating it. See
/// `PrivacyPolicyScreen` / `TermsOfServiceScreen` for the concrete content.
///
/// In-app only: this satisfies "the user can read the policy inside the
/// app", but app-store submission additionally requires a **hosted,
/// external URL** reachable outside the app — see issue #37's PR
/// description and `docs/legal/` for the same text ready to publish
/// elsewhere.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: document.title,
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effective ${document.effectiveDate}',
              style: TwText.textXs.copyWith(color: TwColors.textMuted),
            ),
            const SizedBox(height: TwSpacing.x3_5),
            Text(document.intro, style: TwText.textSm),
            for (final section in document.sections) ...[
              const SizedBox(height: TwSpacing.sectionGap),
              Text(
                section.heading,
                style: TwText.fontBoldSm.copyWith(fontSize: 16),
              ),
              const SizedBox(height: TwSpacing.x2),
              Text(section.body, style: TwText.textSm),
            ],
            const SizedBox(height: TwSpacing.x5),
          ],
        ),
      ),
    );
  }
}
