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
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Stack(
            children: [
              Container(
                width: media.size.width * 0.9,
                height: media.size.height * 0.4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
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
                  style: TwText.text3xl().copyWith(color: TwColors.text),
                ),
                const SizedBox(height: TwSpacing.x3),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TwText.textBase().copyWith(
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
