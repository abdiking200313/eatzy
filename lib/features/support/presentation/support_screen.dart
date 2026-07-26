import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_scaffold.dart';
import 'models/support_models.dart';
import 'widgets/support_cards.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const List<SupportTopic> _helpTopics = [
    SupportTopic(
      icon: Icons.shopping_bag_outlined,
      title: 'Orders & Delivery',
      subtitle: 'Track orders, delivery issues',
    ),
    SupportTopic(
      icon: Icons.payment,
      title: 'Payment & Wallet',
      subtitle: 'Refunds, payment methods',
    ),
    SupportTopic(
      icon: Icons.restaurant,
      title: 'Restaurants & Food',
      subtitle: 'Menu, allergies, restaurant info',
    ),
    SupportTopic(
      icon: Icons.account_circle_outlined,
      title: 'Account',
      subtitle: 'Profile, login, passwords',
    ),
  ];

  static const List<SupportTopic> _contactOptions = [
    SupportTopic(
      icon: Icons.mail_outline,
      title: 'Email Us',
      subtitle: 'support@zivo.com',
    ),
    SupportTopic(
      icon: Icons.phone_outlined,
      title: 'Call Us',
      subtitle: '+234 XXX XXXX XXXX',
    ),
    SupportTopic(
      icon: Icons.chat_outlined,
      title: 'Live Chat',
      subtitle: 'Chat with our team 9AM - 9PM',
    ),
  ];

  static const List<FaqItem> _faqItems = [
    FaqItem(
      question: 'How do I track my order?',
      answer:
          'You can track your order in real-time from the Track Order section. You\'ll receive updates at each stage.',
    ),
    FaqItem(
      question: 'What if my food is late?',
      answer:
          'If your order is delayed, contact our support team for immediate assistance and compensation.',
    ),
    FaqItem(
      question: 'Can I change my order?',
      answer: 'You can modify your order up to 2 minutes after placing it.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Help & Support',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        children: [
          const SectionTitle('How can we help?'),
          const SizedBox(height: TwSpacing.x5),
          for (final topic in _helpTopics) ...[
            HelpCard(topic: topic),
            if (topic != _helpTopics.last) const SizedBox(height: TwSpacing.x5),
          ],
          const SizedBox(height: TwSpacing.x8),
          const SectionTitle('Need more help?', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (final topic in _contactOptions) ...[
            ContactCard(topic: topic),
            if (topic != _contactOptions.last)
              const SizedBox(height: TwSpacing.x5),
          ],
          const SizedBox(height: TwSpacing.x8),
          const SectionTitle('Frequently Asked Questions', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (final faq in _faqItems) ...[
            FaqCard(item: faq),
            if (faq != _faqItems.last) const SizedBox(height: TwSpacing.x5),
          ],
        ],
      ),
    );
  }
}
