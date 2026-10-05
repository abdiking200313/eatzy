import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

/// Zivo's Terms of Service, reachable from Settings → Terms & Conditions
/// (issue #37).
///
/// See `PrivacyPolicyScreen`'s doc comment for the same context on why this
/// text exists and where it came from; this document is deliberately
/// plain-language consumer-app terms, not boilerplate copied from another
/// product, and stays in-app only — see the issue #37 PR description for
/// the external-hosting gap this does not close.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const document = LegalDocument(
    title: 'Terms & Conditions',
    effectiveDate: 'September 14, 2026',
    intro:
        'These Terms of Service ("Terms") govern your use of the Zivo app. '
        'By creating an account or otherwise using the app, you agree to '
        'these Terms. If you do not agree, please do not use the app.',
    sections: [
      LegalSection(
        heading: '1. The Service',
        body:
            'Zivo is a delivery app that connects you to food, grocery, '
            'and pharmacy ordering. Food delivery is fully live today; '
            'grocery and pharmacy ordering are still being built out, so '
            'not every feature described elsewhere in the app is available '
            'in every region yet.',
      ),
      LegalSection(
        heading: '2. Your Account',
        body:
            'You must provide accurate information when creating your '
            'account and keep your profile details up to date. You are '
            'responsible for keeping your password confidential and for '
            'all activity that happens under your account. You must be old '
            'enough to enter into a binding contract under the law that '
            'applies to you to use Zivo.',
      ),
      LegalSection(
        heading: '3. Orders and Payment',
        body:
            'When you place an order, you authorize us to charge your '
            'saved payment method (or use your in-app wallet balance) for '
            'the order total shown at checkout, including any delivery '
            'fees or service charges disclosed before you confirm. Prices, '
            'item availability, and delivery estimates are set by the '
            'restaurant, store, or pharmacy fulfilling your order and are '
            'not guaranteed by Zivo. We do not store your full card '
            'number — only a display-safe brand and last-four reference '
            'from our payment processor.',
      ),
      LegalSection(
        heading: '4. Cancellations and Delivery',
        body:
            'Delivery times shown in the app are estimates, not '
            'guarantees. Orders may be delayed or occasionally canceled '
            'due to circumstances outside our control, such as item '
            'unavailability, weather, or traffic. Cancellation windows and '
            'refund eligibility depend on how far along your order is when '
            'you request a cancellation.',
      ),
      LegalSection(
        heading: '5. Acceptable Use',
        body:
            'You agree not to: place fraudulent orders or use a payment '
            'method you are not authorized to use; attempt to abuse '
            'wallet, promotional, or referral features; interfere with or '
            'disrupt the app\'s normal operation; or attempt to access '
            'another user\'s account or data.',
      ),
      LegalSection(
        heading: '6. Account Termination and Deletion',
        body:
            'You may delete your own account at any time from Settings → '
            'Delete Account, which anonymizes your profile and removes '
            'your saved addresses and payment method references — see the '
            'Privacy Policy for exactly what happens. We may suspend or '
            'terminate an account that we reasonably believe is being used '
            'fraudulently or abusively, or that violates these Terms.',
      ),
      LegalSection(
        heading: '7. Disclaimers and Limitation of Liability',
        body:
            'The app is provided "as is" without warranties of any kind, '
            'to the extent permitted by law. Zivo is not liable for '
            'issues caused by a restaurant, store, pharmacy, or delivery '
            'partner outside our direct control. To the extent permitted '
            'by law, our total liability to you for any claim relating to '
            'the app is limited to the amount you paid us in the 12 months '
            'before the claim arose.',
      ),
      LegalSection(
        heading: '8. Changes to These Terms',
        body:
            'We may update these Terms as the app changes. Material '
            'changes will be reflected with a new effective date at the '
            'top of this page; continuing to use the app after an update '
            'means you accept the revised Terms.',
      ),
      LegalSection(
        heading: '9. Governing Law',
        body:
            'These Terms are governed by the laws that apply in your '
            'place of residence, except where local law requires a '
            'different governing law to apply.',
      ),
      LegalSection(
        heading: '10. Contact Us',
        body: 'Questions about these Terms can be sent to support@zivo.com.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(document: document);
  }
}
