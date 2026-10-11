import { LegalDocumentScreen } from '@/features/legal/legal-document-screen';
import { PRIVACY_POLICY } from '@/features/legal/privacy-policy-document';

// Ports AppRoutes.privacyPolicy ('/settings/privacy-policy') ->
// flutter_app/lib/features/legal/presentation/privacy_policy_screen.dart
// (issue #404 / P8-08).
export default function PrivacyPolicyRoute() {
  return <LegalDocumentScreen document={PRIVACY_POLICY} />;
}
