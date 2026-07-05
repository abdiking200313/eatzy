import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/onboarding_page.dart';

class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  static const String _imageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDKI5m5_n41p6Pp8D5Vj2nTWD5rjR00Bk0cFToAQ0UOPUvc2OQ7eFEyiSAq3Zgkz6oirPHQrUfQBhIk0a-Eu2gp-9ZFnemdbtLgbvZ-oodMR5U0EoselLBnEvemDgnlic_V-aFsctDBS15hMrHmlviju-yQ_zOwF0YiLMOE2Bj_bvwA6Y08OTFmpoc1F2K3VqqG_BC6w95FX6OYe3m3idpa0nbzp4jfvkVsDNUEGVPLTqPjls2tfP4QqCxKfi-ZwIAUWzbcX3du_vZ4';

  @override
  Widget build(BuildContext context) {
    return OnboardingPage(
      imageUrl: _imageUrl,
      title: 'Youth Rewards',
      description:
          'Exclusive deals for students and young foodies. Unlock special perks as you eat!',
      badge: Positioned(
        bottom: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
          child: Row(
            children: [
              const Icon(Icons.stars, color: Colors.white),
              const SizedBox(width: AppSpacing.base),
              Text(
                '50% OFF',
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
