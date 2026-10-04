import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // A wide, shallow card (~176 tall at default text scale) rather than
      // the previous content-hugging block, so the banner reads as a
      // distinct promo/discount strip instead of another text section. A
      // minimum rather than a fixed height so it can still grow to fit
      // larger text scales instead of overflowing.
      constraints: const BoxConstraints(minHeight: 176),
      child: Container(
        width: double.infinity,
        // 22: literal per the "1a" spec's hero-banner inner padding (no
        // token at this value).
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: TwColors.primaryGradient,
          borderRadius: BorderRadius.circular(TwRadius.hero),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // spaceBetween (not center): title top-left, CTA bottom-left
                // per the "1a" spec, now that the banner is taller.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Everything nearby,\none tap away',
                    style: TwText.textLg.copyWith(
                      color: TwColors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x3),
                  OutlinedButton(
                    onPressed: onExplore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TwColors.white,
                      side: const BorderSide(color: TwColors.white),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TwSpacing.x4,
                      ),
                    ),
                    child: const Text('Explore'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TwSpacing.x3),
            // Icon sits in a soft circular badge so it reads as a small
            // illustration rather than a bare glyph floating in the card.
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: TwColors.white.withOpacityValue(0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: TwColors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
