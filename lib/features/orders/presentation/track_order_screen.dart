import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_misc.dart';
import '../../../widgets/app_scaffold.dart';

class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key});

  static const String _courierImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAFRHg36EQATUqDhYD94R_K05G_f_-4ocNsdVBQUVTX8xvKbpdmSknU7GmZePTgv4lBF85k0RDyrmnlfs2PK53uCy3GJCX-D--qbu1fE71RUty6lSxYRFbaGWOOlbJXVqBEcr0UyXTpyWdZPmjRyEUF1OHHnMx-xCvUUimbd_auXDxH-k66vULm46he9xSs-oD00XaZzS3nF9H6yAXrF6_RTe3YZfKuK56TfbmvM9woXHeOrwZGm0mMP7mewgHD325vsNshlQvqaSTD';

  static const List<_TimelineStep> _steps = [
    _TimelineStep(
      label: 'Order Confirmed',
      isCompleted: true,
      hasConnector: true,
    ),
    _TimelineStep(label: 'Preparing', isCompleted: true, hasConnector: true),
    _TimelineStep(
      label: 'Out for Delivery',
      isCompleted: true,
      hasConnector: false,
    ),
    _TimelineStep(label: 'Delivered', isCompleted: false, hasConnector: false),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Track Order',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(TwSpacing.x5),
        children: [
          OutlinedCard(
            backgroundColor: Colors.white,
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #45782', style: TwText.fontBoldBase()),
                    const StatusPill(
                      label: 'On the way',
                      backgroundColor: TwColors.blue400,
                      foregroundColor: TwColors.text,
                    ),
                  ],
                ),
                const SizedBox(height: TwSpacing.x5),
                for (final step in _steps) _TimelineStepRow(step: step),
              ],
            ),
          ),
          const SizedBox(height: TwSpacing.x8),
          Container(
            padding: const EdgeInsets.all(TwSpacing.x5),
            decoration: BoxDecoration(
              gradient: TwColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const NetworkAvatar(imageUrl: _courierImageUrl, radius: 35),
                const SizedBox(width: TwSpacing.x5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Partner',
                        style: TwText.textXs().copyWith(
                          color: Colors.white.withOpacityValue(0.8),
                        ),
                      ),
                      Text(
                        'Yusuf Adeyemi',
                        style: TwText.fontBoldBase().copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.white),
                          const SizedBox(width: TwSpacing.x1),
                          Text(
                            '4.9',
                            style: TwText.textXs().copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: TwSpacing.x8),
          OutlinedCard(
            backgroundColor: TwColors.cardMuted,
            borderRadius: 16,
            child: Column(
              children: [
                Text(
                  'Estimated Arrival',
                  style: TwText.textXs().copyWith(color: TwColors.textMuted),
                ),
                const SizedBox(height: TwSpacing.x2),
                Text(
                  '12 minutes',
                  style: TwText.text3xl().copyWith(color: TwColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStepRow extends StatelessWidget {
  const _TimelineStepRow({required this.step});

  final _TimelineStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpacing.x2),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: step.isCompleted
                      ? TwColors.primary
                      : TwColors.borderStrong,
                  borderRadius: BorderRadius.circular(TwRadius.full),
                ),
                child: step.isCompleted
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (step.hasConnector)
                Container(width: 2, height: 40, color: TwColors.primary),
            ],
          ),
          const SizedBox(width: TwSpacing.x5),
          Text(
            step.label,
            style: TwText.fontBoldSm().copyWith(
              color: step.isCompleted ? TwColors.text : TwColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.label,
    required this.isCompleted,
    required this.hasConnector,
  });

  final String label;
  final bool isCompleted;
  final bool hasConnector;
}
