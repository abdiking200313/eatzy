import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_misc.dart';
import '../models/support_models.dart';

/// A single help-topic row. Rendered bare so [SupportScreen] can compose
/// several rows inside one shared `OutlinedCard` with internal dividers —
/// "one card per list, not one card per row" (#21/#27).
class HelpCard extends StatelessWidget {
  const HelpCard({super.key, required this.topic});

  final SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          ServiceIconChip(
            icon: topic.icon,
            background: palette.soft,
            foreground: palette.accent,
          ),
          const SizedBox(width: TwSpacing.x4),
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

/// A single contact-option row. Rendered bare so [SupportScreen] can
/// compose several rows inside one shared `OutlinedCard` with internal
/// dividers — "one card per list, not one card per row" (#21/#27).
class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.topic});

  final SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Row(
        children: [
          ServiceIconChip(
            icon: topic.icon,
            background: palette.soft,
            foreground: palette.accent,
          ),
          const SizedBox(width: TwSpacing.x4),
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
          Icon(Icons.arrow_forward_rounded, size: 18, color: palette.accent),
        ],
      ),
    );
  }
}

/// A single FAQ entry. Rendered bare so [SupportScreen] can compose several
/// entries inside one shared `OutlinedCard` with internal dividers — "one
/// card per list, not one card per row" (#21/#27).
class FaqCard extends StatelessWidget {
  const FaqCard({super.key, required this.item});

  final FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.rhythmDefault,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.question, style: TwText.fontBoldSm()),
          const SizedBox(height: TwSpacing.rhythmTight),
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
