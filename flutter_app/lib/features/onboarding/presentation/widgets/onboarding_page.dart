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

  /// Height from the top of the welcome screen's pinned page dots to the
  /// bottom of the screen (dots, "Get Started", "Log In" and their spacing),
  /// so the slide centers in what is left above them rather than behind
  /// them. Roughly 120px of fixed spacing plus 52px of text-driven height
  /// (the button label and login row), which grows with the text scale.
  static double _bottomControlsClearance(BuildContext context) =>
      120 + 52 * MediaQuery.textScalerOf(context).scale(1);

  @override
  Widget build(BuildContext context) {
    // The slide sits under the welcome screen's transparent app bar, so
    // clear it (status bar + toolbar) before centering.
    final headerClearance = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomClearance = _bottomControlsClearance(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          // At least the viewport tall, so `Center` has room to center the
          // group; taller content just scrolls, as before.
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            // Asymmetric padding inside `Center` puts the group's midpoint
            // halfway between the header and the bottom controls.
            child: Padding(
              padding: EdgeInsets.only(
                top: headerClearance,
                bottom: bottomClearance,
              ),
              child: Column(
                key: const Key('onboarding-block'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TwSpacing.x5,
                    ),
                    child: content,
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TwSpacing.x5,
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
