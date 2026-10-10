import { LegalDocumentScreen } from '@/features/legal/legal-document-screen';
import { TERMS_OF_SERVICE } from '@/features/legal/terms-of-service-document';

// Ports AppRoutes.termsOfService ('/settings/terms-of-service') ->
// flutter_app/lib/features/legal/presentation/terms_of_service_screen.dart
// (issue #404 / P8-08).
export default function TermsOfServiceRoute() {
  return <LegalDocumentScreen document={TERMS_OF_SERVICE} />;
}
