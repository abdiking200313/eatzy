import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../models/support_models.dart';

class HelpCard extends StatelessWidget {
  const HelpCard({super.key, required this.topic});

  final SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(TwRadius.lg),
            ),
            child: Icon(topic.icon, color: palette.accent),
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
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
    final palette = context.serviceColors;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      backgroundColor: palette.soft,
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(TwRadius.lg),
            ),
            child: Icon(topic.icon, color: palette.accent),
          ),
          const SizedBox(width: TwSpacing.x5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title, style: TwText.fontBoldSm()),
                Text(
                  topic.subtitle,
                  style: TwText.textXs().copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, size: 18, color: palette.accent),
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
      padding: const EdgeInsets.all(TwSpacing.x4),
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
