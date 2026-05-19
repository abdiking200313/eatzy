import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

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
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuDZLUWZadudBWsyYKgGCkjUrQyMdxksKVC4SiSTuS9auYSR6y6goKHt4FgN1xc1h0_lGpVVzQ09jRibGAaZ0ZYZd49C4M82QbAp1ZLLJoA4sBa_79n9PfZCDypw68CDwHjgV4ccVSmZLCFJW9jqqXEodoJdVDpdoZ8rc62dhvZfvcfyIqe1zJ-zKnZpHZnqYGey7CxH4ybCjEyAM_gphReAWQfzIyrkGwToZM_ZmRpzWnlk20NUE7bMxL45EXInYq7b5_LwMCkQfLpE'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacityValue(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacityValue(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(Icons.electric_scooter,
                            color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Column(
                        children: [
                          Text(
                            'ETA',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacityValue(0.8),
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            '12 Minutes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
                  'Quick & Easy',
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
                  'Order in a few taps and track your meal in real-time with our lightning-fast service.',
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