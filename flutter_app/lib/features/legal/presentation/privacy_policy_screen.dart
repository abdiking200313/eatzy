import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

/// Zivo's Privacy Policy, reachable from Settings → Privacy Policy
/// (issue #37).
///
/// The text below reflects what the app actually collects, derived from a
/// codebase scan rather than boilerplate: Supabase auth (email/password),
/// `profiles` (name, phone, avatar), `delivery_addresses`, order history
/// across the food/grocery/pharmacy verticals, `payment_methods` (brand +
/// last four only — never a full card number), `wallet_transactions`,
/// locally-stored notification preferences, and the two third-party hosts
/// issue #37 called out (`fonts.gstatic.com` via `google_fonts`,
/// `lh3.googleusercontent.com` for onboarding illustration images). The
/// account-deletion section matches `delete_own_account` (issue #36)
/// exactly — see `lib/features/profile/data/profile_repository.dart` and
/// `supabase/migrations/20260919000000_add_delete_own_account_rpc.sql`.
///
/// This screen is in-app content, not a hosted external page — see
/// `LegalDocumentScreen`'s doc comment and the issue #37 PR description for
/// the app-store-submission gap this does not close.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const document = LegalDocument(
    title: 'Privacy Policy',
    effectiveDate: 'September 14, 2026',
    intro:
        'This Privacy Policy explains what information Zivo ("the app", '
        '"we", "us") collects when you use the app, why we collect it, who '
        'we share it with, and the choices you have. Zivo is a food, '
        'grocery, and pharmacy delivery app. By creating an account and '
        'using Zivo, you agree to the collection and use of information as '
        'described here.',
    sections: [
      LegalSection(
        heading: '1. Information We Collect',
        body:
            'Account information: your email address and password, '
            'collected and managed through our authentication provider '
            '(Supabase) when you sign up or sign in.\n\n'
            'Profile information: your first name, last name, phone '
            'number, and (optional) a profile picture, which you provide '
            'when you edit your profile.\n\n'
            'Delivery addresses: the recipient name, phone number, street, '
            'district/neighborhood, and city for each address you save, so '
            'we can deliver your orders to the right place.\n\n'
            'Order history: the food, grocery, and pharmacy orders you '
            'place, including the items ordered, order status, the '
            'delivery address used, and order totals.\n\n'
            'Payment information: we store a display-safe reference to '
            'your saved payment methods — card brand and last four digits '
            'only. We do not collect or store your full card number, CVV, '
            'or bank credentials on our own servers.\n\n'
            'Wallet activity: your in-app wallet balance and transaction '
            'history.\n\n'
            'Notification preferences: your push/email/promotional/order-'
            'update toggle choices. These are stored locally on your '
            'device, not on our servers.\n\n'
            'Diagnostic information: basic error and crash details, so we '
            'can find and fix problems in the app.',
      ),
      LegalSection(
        heading: '2. How We Use Your Information',
        body:
            'We use the information above to: create and manage your '
            'account and keep your session secure; process and deliver '
            'your orders, including matching the correct delivery address '
            'and sending order-status updates; let you save and reuse '
            'delivery addresses and payment methods for faster checkout; '
            'send notifications you have opted into, including promotional '
            'messages if you leave that toggle on; diagnose and fix crashes '
            'or errors; and keep records needed for accounting, taxation, '
            'or dispute resolution.',
      ),
      LegalSection(
        heading: '3. Third-Party Services',
        body:
            'Supabase (authentication and database hosting) stores your '
            'account, profile, address, order, wallet, and payment-'
            'reference data on our behalf. Access to this data is '
            'restricted with row-level security so that only your own '
            'signed-in session — never another user — can read or write '
            'your rows.\n\n'
            'Google Fonts (fonts.gstatic.com): the app downloads font '
            'files from Google\'s font hosting at runtime to render text. '
            'Google may log standard request metadata (such as your IP '
            'address) for these requests; no Zivo account data is sent '
            'along with them.\n\n'
            'Google-hosted images (lh3.googleusercontent.com): a small '
            'number of onboarding illustration images are served from '
            'Google\'s content hosting. No user or account data is sent '
            'with these requests either.\n\n'
            'We do not sell your personal information to anyone.',
      ),
      LegalSection(
        heading: '4. Data Retention',
        body:
            'Your profile, saved addresses, wallet, and payment-reference '
            'data are kept for as long as your account is active. Order '
            'history is retained after account deletion for accounting and '
            'dispute-resolution purposes, but is no longer linked to a '
            'readable profile once your account has been deleted (see '
            'below). Notification preferences live only on your device and '
            'are cleared automatically if you uninstall the app.',
      ),
      LegalSection(
        heading: '5. Your Rights and Choices',
        body:
            'You can view and edit your profile name and phone number at '
            'any time from Settings. You can add, edit, or remove your '
            'saved delivery addresses at any time. You can turn '
            'notification toggles on or off at any time from Settings.\n\n'
            'You can delete your account directly in the app: Settings → '
            'Delete Account. This clears your profile\'s name, phone '
            'number, and profile picture, and permanently deletes your '
            'saved delivery addresses and payment method references. Past '
            'order records are kept in de-identified form for the '
            'recordkeeping reasons described above, rather than deleted '
            'outright, since deleting the underlying order tables would '
            'also break other customers\' and the business\'s own order '
            'history.\n\n'
            'You can also contact us (below) with any question about your '
            'data or a request that isn\'t covered by the in-app tools.',
      ),
      LegalSection(
        heading: '6. Data Security',
        body:
            'Your data is protected by Supabase row-level security '
            'policies, so only your own signed-in session can read or '
            'write your account\'s rows. We never store your full payment '
            'card number on our own servers.',
      ),
      LegalSection(
        heading: '7. Children\'s Privacy',
        body:
            'Zivo is not directed at children under 13, and we do not '
            'knowingly collect information from children under 13.',
      ),
      LegalSection(
        heading: '8. Changes to This Policy',
        body:
            'We may update this policy as the app changes. Material '
            'changes will be reflected with a new effective date at the '
            'top of this page.',
      ),
      LegalSection(
        heading: '9. Contact Us',
        body:
            'Questions about this policy or your data can be sent to '
            'support@zivo.com.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(document: document);
  }
}
