import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../models/support_models.dart';

class HelpCard extends StatelessWidget {
  const HelpCard({super.key, required this.topic});

  final SupportTopic topic;

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

class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.topic});

  final SupportTopic topic;

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

class FaqCard extends StatelessWidget {
  const FaqCard({super.key, required this.item});

  final FaqItem item;

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
