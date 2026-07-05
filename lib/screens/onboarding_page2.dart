import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/onboarding_page.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  static const String _imageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDZLUWZadudBWsyYKgGCkjUrQyMdxksKVC4SiSTuS9auYSR6y6goKHt4FgN1xc1h0_lGpVVzQ09jRibGAaZ0ZYZd49C4M82QbAp1ZLLJoA4sBa_79n9PfZCDypw68CDwHjgV4ccVSmZLCFJW9jqqXEodoJdVDpdoZ8rc62dhvZfvcfyIqe1zJ-zKnZpHZnqYGey7CxH4ybCjEyAM_gphReAWQfzIyrkGwToZM_ZmRpzWnlk20NUE7bMxL45EXInYq7b5_LwMCkQfLpE';

  @override
  Widget build(BuildContext context) {
    return OnboardingPage(
      imageUrl: _imageUrl,
      title: 'Quick & Easy',
      description:
          'Order in a few taps and track your meal in real-time with our lightning-fast service.',
      badge: Positioned(
        top: 16,
        left: 16,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: Colors.white.withOpacityValue(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacityValue(0.3),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: const Icon(
                  Icons.electric_scooter,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ETA',
                style: AppTextStyles.labelSm().copyWith(
                  color: Colors.white.withOpacityValue(0.8),
                  letterSpacing: 1,
                ),
              ),
              Text(
                '12 Minutes',
                style: AppTextStyles.labelBold().copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
