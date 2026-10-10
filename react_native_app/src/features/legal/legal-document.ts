/**
 * Ports `LegalSection` / `LegalDocument` from
 * flutter_app/lib/features/legal/presentation/legal_document_screen.dart.
 */

/**
 * One labeled paragraph (or group of paragraphs) inside a `LegalDocument`.
 * `body` may contain blank lines (`\n\n`) separating multiple paragraphs;
 * `LegalDocumentScreen` renders it verbatim.
 */
export type LegalSection = {
  heading: string;
  body: string;
};

/** The full text of a static legal document (Privacy Policy, Terms, ...). */
export type LegalDocument = {
  title: string;
  /** e.g. "September 14, 2026" -- shown under the title as "Effective ...". */
  effectiveDate: string;
  /** A short paragraph shown before the first numbered section. */
  intro: string;
  sections: readonly LegalSection[];
};
