import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  image: const DecorationImage(
                    image: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuDKI5m5_n41p6Pp8D5Vj2nTWD5rjR00Bk0cFToAQ0UOPUvc2OQ7eFEyiSAq3Zgkz6oirPHQrUfQBhIk0a-Eu2gp-9ZFnemdbtLgbvZ-oodMR5U0EoselLBnEvemDgnlic_V-aFsctDBS15hMrHmlviju-yQ_zOwF0YiLMOE2Bj_bvwA6Y08OTFmpoc1F2K3VqqG_BC6w95FX6OYe3m3idpa0nbzp4jfvkVsDNUEGVPLTqPjls2tfP4QqCxKfi-ZwIAUWzbcX3du_vZ4'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.white),
                      const SizedBox(width: AppSpacing.base),
                      Text(
                        '50% OFF',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'Youth Rewards',
                  style: GoogleFonts.epilogue(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Exclusive deals for students and young foodies. Unlock special perks as you eat!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
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