import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// A reusable onboarding slide layout: a per-screen illustration/content
/// area on top, then a headline and a muted description below it.
///
/// Issue #233 replaced the original hero-photo design (a
/// `lh3.googleusercontent.com/aida-public/...` Google Stitch design-tool
/// URL — an ephemeral third-party CDN host the project doesn't control, see
/// issue #44) with purpose-built local widgets for each slide's content
/// area, so this shell no longer needs any network-image machinery.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.content,
    required this.title,
    required this.description,
  });

  /// The per-screen illustration area (e.g. a restaurant list, an order
  /// summary card, or a delivery-tracking card).
  final Widget content;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 96),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            child: content,
          ),
          const SizedBox(height: TwSpacing.x8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TwSpacing.x5),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TwText.text3xl.copyWith(color: TwColors.text),
                ),
                const SizedBox(height: TwSpacing.x3),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TwText.textBase.copyWith(
                    color: TwColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
