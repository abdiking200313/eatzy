import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

class SupportScreenFull extends StatelessWidget {
  const SupportScreenFull({super.key});

  static const List<_SupportTopic> _helpTopics = [
    _SupportTopic(
      icon: Icons.shopping_bag_outlined,
      title: 'Orders & Delivery',
      subtitle: 'Track orders, delivery issues',
    ),
    _SupportTopic(
      icon: Icons.payment,
      title: 'Payment & Wallet',
      subtitle: 'Refunds, payment methods',
    ),
    _SupportTopic(
      icon: Icons.restaurant,
      title: 'Restaurants & Food',
      subtitle: 'Menu, allergies, restaurant info',
    ),
    _SupportTopic(
      icon: Icons.account_circle_outlined,
      title: 'Account',
      subtitle: 'Profile, login, passwords',
    ),
  ];

  static const List<_SupportTopic> _contactOptions = [
    _SupportTopic(
      icon: Icons.mail_outline,
      title: 'Email Us',
      subtitle: 'support@zivo.com',
    ),
    _SupportTopic(
      icon: Icons.phone_outlined,
      title: 'Call Us',
      subtitle: '+234 XXX XXXX XXXX',
    ),
    _SupportTopic(
      icon: Icons.chat_outlined,
      title: 'Live Chat',
      subtitle: 'Chat with our team 9AM - 9PM',
    ),
  ];

  static const List<_FaqItem> _faqItems = [
    _FaqItem(
      question: 'How do I track my order?',
      answer:
          'You can track your order in real-time from the Track Order section. You\'ll receive updates at each stage.',
    ),
    _FaqItem(
      question: 'What if my food is late?',
      answer:
          'If your order is delayed, contact our support team for immediate assistance and compensation.',
    ),
    _FaqItem(
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
            _HelpCard(topic: topic),
            if (topic != _helpTopics.last) const SizedBox(height: TwSpacing.x5),
          ],
          const SizedBox(height: TwSpacing.x8),
          const SectionTitle('Need more help?', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (final topic in _contactOptions) ...[
            _ContactCard(topic: topic),
            if (topic != _contactOptions.last)
              const SizedBox(height: TwSpacing.x5),
          ],
          const SizedBox(height: TwSpacing.x8),
          const SectionTitle('Frequently Asked Questions', fontSize: 18),
          const SizedBox(height: TwSpacing.x5),
          for (final faq in _faqItems) ...[
            _FaqCard(item: faq),
            if (faq != _faqItems.last) const SizedBox(height: TwSpacing.x5),
          ],
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.topic});

  final _SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: TwColors.primaryAccent.withOpacityValue(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(topic.icon, color: TwColors.primary),
          ),
          const SizedBox(width: TwSpacing.x5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title, style: TwText.fontBoldSm()),
                Text(
                  topic.subtitle,
                  style: TwText.textXs().copyWith(color: TwColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.topic});

  final _SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TwSpacing.x5),
      decoration: BoxDecoration(
        gradient: TwColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withOpacityValue(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(topic.icon, color: Colors.white),
          ),
          const SizedBox(width: TwSpacing.x5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: TwText.fontBoldSm().copyWith(color: Colors.white),
                ),
                Text(
                  topic.subtitle,
                  style: TwText.textXs().copyWith(
                    color: Colors.white.withOpacityValue(0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.question, style: TwText.fontBoldSm()),
          const SizedBox(height: TwSpacing.x2),
          Text(
            item.answer,
            style: TwText.textXs().copyWith(
              color: TwColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTopic {
  const _SupportTopic({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}
