import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// A reusable onboarding slide that combines a hero image, an optional
/// floating badge, a heading and a description.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,
    this.badge,
  });

  final String imageUrl;
  final String title;
  final String description;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroWidth = media.size.width * 0.9;
    final heroHeight = media.size.height * 0.4;
    // Decode at roughly the rendered hero box (90% of screen width, 40%
    // of screen height) scaled for device pixel density. Capped at 3x
    // since a wider cap buys no visible sharpness while still inflating
    // decode memory.
    final cacheScale = media.devicePixelRatio.clamp(1.0, 3.0);
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Stack(
            children: [
              Container(
                width: heroWidth,
                height: heroHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TwRadius.xl),
                  border: Border.all(color: TwColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: TwColors.slate900.withOpacityValue(0.1),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: heroWidth,
                  height: heroHeight,
                  memCacheWidth: (heroWidth * cacheScale).round(),
                  memCacheHeight: (heroHeight * cacheScale).round(),
                  placeholder: (_, _) =>
                      const _OnboardingImageFallback(showLoader: true),
                  errorWidget: (_, _, _) => const _OnboardingImageFallback(),
                ),
              ),
              ?badge,
            ],
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

/// Loading/error placeholder for the onboarding hero image, matching the
/// fallback pattern used by other `CachedNetworkImage` call sites in the
/// app (a neutral tinted box with a centered icon or spinner).
class _OnboardingImageFallback extends StatelessWidget {
  const _OnboardingImageFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TwColors.cardMuted,
      child: Center(
        child: showLoader
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(
                Icons.image_outlined,
                color: TwColors.textMuted,
                size: 42,
              ),
      ),
    );
  }
}
