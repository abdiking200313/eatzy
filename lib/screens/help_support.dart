import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class HelpSupportScreenFull extends StatefulWidget {
  const HelpSupportScreenFull({super.key});

  @override
  State<HelpSupportScreenFull> createState() => _HelpSupportScreenFullState();
}

class _HelpSupportScreenFullState extends State<HelpSupportScreenFull> {
  List<Map<String, dynamic>> faqItems = [
    {
      'question': 'How do I track my order?',
      'answer': 'You can track your order in real-time from the My Orders section. Tap on any active order to see the delivery status and estimated arrival time.',
      'isExpanded': false,
    },
    {
      'question': 'What payment methods are accepted?',
      'answer': 'We accept all major credit/debit cards, digital wallets, and cash on delivery. You can manage your payment methods in the Payment Methods section.',
      'isExpanded': false,
    },
    {
      'question': 'How can I cancel my order?',
      'answer': 'You can cancel orders that are in "Confirmed" status. Go to My Orders, tap on the order, and select Cancel Order. Refunds are processed within 5-7 business days.',
      'isExpanded': false,
    },
    {
      'question': 'Is there a delivery fee?',
      'answer': 'Delivery fees vary based on your location and the restaurant. You can see the exact fee during checkout before placing your order.',
      'isExpanded': false,
    },
    {
      'question': 'How do I contact customer support?',
      'answer': 'You can reach our support team 24/7 through the Help & Support section using phone, email, or in-app chat. We typically respond within 2 hours.',
      'isExpanded': false,
    },
  ];

  final List<Map<String, dynamic>> helpCategories = [
    {
      'title': 'Track Order',
      'icon': Icons.local_shipping_outlined,
      'description': 'Real-time order tracking',
    },
    {
      'title': 'Payment Issues',
      'icon': Icons.payment_outlined,
      'description': 'Payment and billing help',
    },
    {
      'title': 'Delivery Problems',
      'icon': Icons.location_on_outlined,
      'description': 'Address and delivery assistance',
    },
    {
      'title': 'Account Help',
      'icon': Icons.account_circle_outlined,
      'description': 'Account management support',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Help & Support',
          style: GoogleFonts.epilogue(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        foregroundColor: AppColors.onSurface,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.fireSunGradient,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Icon(Icons.email_outlined, color: Colors.white, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contact Support',
                            style: GoogleFonts.epilogue(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Available 24/7 via phone, email, or chat',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white.withOpacityValue(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Help Categories
              Text(
                'Help Categories',
                style: GoogleFonts.epilogue(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: helpCategories.length,
                itemBuilder: (context, index) {
                  return _buildHelpCategoryCard(helpCategories[index]);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // FAQ Section
              Text(
                'Frequently Asked Questions',
                style: GoogleFonts.epilogue(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: faqItems.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _buildFAQItem(index),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpCategoryCard(Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category['icon'],
              color: AppColors.primary,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              category['title'],
              style: GoogleFonts.epilogue(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                textBaseline: TextBaseline.alphabetic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              category['description'],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(int index) {
    final item = faqItems[index];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.onSurfaceVariant,
          onExpansionChanged: (isExpanded) {
            setState(() {
              faqItems[index]['isExpanded'] = isExpanded;
            });
          },
          title: Text(
            item['question'],
            style: GoogleFonts.epilogue(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
              child: Text(
                item['answer'],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
