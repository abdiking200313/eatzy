import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              image: const DecorationImage(
                image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBp46EkqrfNbM77LtYuXz73MURfba6PU8YHL_6IilWwsTX2a9e68bK2MTpd9rFs4YgxPPxAJmURHlPQrinOWSYUtjSmTxHGsmJZcNvt4pGVvtN71M-UXlr7dKTERj4jKA_QEtlxcTwYgY-jT9AvFHv6g3fLeHPT-dK6DdFhAwf_BD1j-oFN_Is7qlXP1B4ZoC6PwaYR3sxSt6X2_py7PmE_noxR8dbr_JIkCOZ5boizVIhTScGAunlmMXosFFGYp3rg0Z4XnbIZRIeS'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'Discover Flavors',
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
                  'Find the best local and trending dishes curated just for your vibrant lifestyle.',
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