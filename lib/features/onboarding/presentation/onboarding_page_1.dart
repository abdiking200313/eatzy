import 'package:flutter/material.dart';

import 'widgets/onboarding_page.dart';

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  static const String _imageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBp46EkqrfNbM77LtYuXz73MURfba6PU8YHL_6IilWwsTX2a9e68bK2MTpd9rFs4YgxPPxAJmURHlPQrinOWSYUtjSmTxHGsmJZcNvt4pGVvtN71M-UXlr7dKTERj4jKA_QEtlxcTwYgY-jT9AvFHv6g3fLeHPT-dK6DdFhAwf_BD1j-oFN_Is7qlXP1B4ZoC6PwaYR3sxSt6X2_py7PmE_noxR8dbr_JIkCOZ5boizVIhTScGAunlmMXosFFGYp3rg0Z4XnbIZRIeS';

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage(
      imageUrl: _imageUrl,
      title: 'Discover Flavors',
      description:
          'Find the best local and trending dishes curated just for your vibrant lifestyle.',
    );
  }
}
