import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// A minimal, static "About" surface for the Settings screen's About Us
/// row.
///
/// Zivo has no CMS-backed about content or app-version reader wired up yet,
/// so this intentionally stays a small static sheet (app identity plus a
/// one-line description) rather than a new routed screen or a dependency
/// on a package-info plugin — either would be out of scope for issue #10.
class AboutZivoSheet extends StatelessWidget {
  const AboutZivoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TwSpacing.x5,
        TwSpacing.rhythmTight,
        TwSpacing.x5,
        TwSpacing.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zivo', style: TwText.textXl),
          const SizedBox(height: TwSpacing.rhythmTight),
          Text(
            'Version 1.0.0',
            style: TwText.textXs.copyWith(color: TwColors.textMuted),
          ),
          const SizedBox(height: TwSpacing.rhythmDefault),
          Text(
            'Zivo is a modular delivery app. Food delivery is live today, '
            'with grocery and pharmacy ordering on the way.',
            style: TwText.textSm,
          ),
        ],
      ),
    );
  }
}
