import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import 'widgets/onboarding_page.dart';

/// Screen 3 of the redesigned onboarding flow (issue #233): "Know Exactly
/// When It Lands" — a dark delivery-status card with a stage progress bar,
/// plus a simple status timeline below it. Sample/placeholder content for
/// the mockup, not real tracking data.
class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage(
      title: 'Know Exactly When It Lands',
      description: 'Live updates from the kitchen to your door, no guessing.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeliveryStatusCard(),
          SizedBox(height: TwSpacing.x5),
          _StatusTimeline(),
        ],
      ),
    );
  }
}

class _DeliveryStatusCard extends StatelessWidget {
  const _DeliveryStatusCard();

  // Two of the three stages (order confirmed, cooking) are already behind
  // the rider being "on the way" with a live countdown, so two segments are
  // filled and the final delivery leg is still in progress.
  static const int _segmentsFilled = 2;
  static const int _segmentCount = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TwSpacing.x5),
      decoration: BoxDecoration(
        color: TwColors.slate900,
        borderRadius: BorderRadius.circular(TwRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'On the way',
                style: TwText.fontBoldBase.copyWith(color: TwColors.white),
              ),
              Text(
                '12 min',
                style: TwText.fontBoldBase.copyWith(color: TwColors.white),
              ),
            ],
          ),
          const SizedBox(height: TwSpacing.x4),
          Row(
            children: [
              for (var i = 0; i < _segmentCount; i++) ...[
                if (i > 0) const SizedBox(width: TwSpacing.x1),
                Expanded(child: _ProgressSegment(filled: i < _segmentsFilled)),
              ],
            ],
          ),
          const SizedBox(height: TwSpacing.x4),
          Text(
            '2 items from Ayam Penyet Ria',
            style: TwText.textSm.copyWith(
              color: TwColors.white.withOpacityValue(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: filled
            ? TwColors.primary
            : TwColors.white.withOpacityValue(0.15),
        borderRadius: BorderRadius.circular(TwRadius.full),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline();

  static const List<_TimelineEntry> _entries = [
    _TimelineEntry(label: 'Order confirmed', time: '9:22 pm'),
    _TimelineEntry(label: 'Cooking', time: '9:28 pm'),
    _TimelineEntry(label: 'Rider picked up', time: '9:36 pm'),
  ];

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      child: Column(
        children: [
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0) const SizedBox(height: TwSpacing.x3),
            _TimelineRow(
              entry: _entries[i],
              isLatest: i == _entries.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLatest});

  final _TimelineEntry entry;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final labelStyle = isLatest
        ? TwText.fontBoldBase
        : TwText.textBase.copyWith(color: TwColors.textMuted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(entry.label, style: labelStyle),
        Text(
          entry.time,
          style: TwText.textSm.copyWith(color: TwColors.textMuted),
        ),
      ],
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({required this.label, required this.time});

  final String label;
  final String time;
}
