/**
 * Issue #404 / P8-08. Ports flutter_app/test/legal_screens_test.dart: smoke
 * tests that each legal screen renders its title, effective date and every
 * section heading. Navigation from Settings into these routes is covered by
 * src/features/settings/settings-screen.test.tsx.
 *
 * The route files under src/app/(app)/settings/ are rendered directly so
 * this also proves `AppRoutes.privacyPolicy` / `AppRoutes.termsOfService`
 * serve the real screens rather than the old route-skeleton placeholders.
 */
import { renderWithProviders } from '@/test-utils';

import PrivacyPolicyRoute from '@/app/(app)/settings/privacy-policy';
import TermsOfServiceRoute from '@/app/(app)/settings/terms-of-service';

import type { LegalDocument } from './legal-document';
import { LegalDocumentScreen } from './legal-document-screen';
import { PRIVACY_POLICY } from './privacy-policy-document';
import { TERMS_OF_SERVICE } from './terms-of-service-document';

describe('legal screens', () => {
  it('PrivacyPolicyScreen renders its title and every section heading', async () => {
    const { getAllByText, getByText, getByLabelText } = await renderWithProviders(<PrivacyPolicyRoute />);

    expect(getAllByText('Privacy Policy').length).toBeGreaterThan(0);
    expect(getAllByText(/Effective September 14, 2026/)).toHaveLength(1);
    expect(getByLabelText('Back')).toBeOnTheScreen();
    for (const section of PRIVACY_POLICY.sections) {
      expect(getByText(section.heading)).toBeOnTheScreen();
    }
    // The two third-party hosts must be named in the policy text, not
    // just implied.
    expect(getAllByText(/fonts\.gstatic\.com/)).toHaveLength(1);
    expect(getAllByText(/lh3\.googleusercontent\.com/)).toHaveLength(1);
    // The account-deletion path must be referenced honestly.
    expect(getAllByText(/Delete Account/)).toHaveLength(1);
  });

  it('TermsOfServiceScreen renders its title and every section heading', async () => {
    const { getAllByText, getByText } = await renderWithProviders(<TermsOfServiceRoute />);

    expect(getAllByText('Terms & Conditions').length).toBeGreaterThan(0);
    expect(getAllByText(/Effective September 14, 2026/)).toHaveLength(1);
    for (const section of TERMS_OF_SERVICE.sections) {
      expect(getByText(section.heading)).toBeOnTheScreen();
    }
  });

  it('LegalDocumentScreen renders an arbitrary document (reusability check)', async () => {
    const document: LegalDocument = {
      title: 'Sample Document',
      effectiveDate: 'January 1, 2030',
      intro: 'An intro paragraph.',
      sections: [
        { heading: 'Heading One', body: 'Body one.' },
        { heading: 'Heading Two', body: 'Body two.' },
      ],
    };

    const { getAllByText, getByText } = await renderWithProviders(<LegalDocumentScreen document={document} />);

    expect(getAllByText('Sample Document').length).toBeGreaterThan(0);
    expect(getAllByText(/January 1, 2030/)).toHaveLength(1);
    expect(getByText('An intro paragraph.')).toBeOnTheScreen();
    expect(getByText('Heading One')).toBeOnTheScreen();
    expect(getByText('Body two.')).toBeOnTheScreen();
  });

  it('renders multi-paragraph section bodies verbatim', async () => {
    const { getByText } = await renderWithProviders(<PrivacyPolicyRoute />);

    for (const section of PRIVACY_POLICY.sections) {
      expect(getByText(section.body)).toBeOnTheScreen();
    }
    expect(PRIVACY_POLICY.sections[0].body).toContain('\n\nProfile information:');
  });
});
