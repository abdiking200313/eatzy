import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class TrackOrderScreenFull extends StatelessWidget {
  const TrackOrderScreenFull({super.key});

  static const String _courierImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAFRHg36EQATUqDhYD94R_K05G_f_-4ocNsdVBQUVTX8xvKbpdmSknU7GmZePTgv4lBF85k0RDyrmnlfs2PK53uCy3GJCX-D--qbu1fE71RUty6lSxYRFbaGWOOlbJXVqBEcr0UyXTpyWdZPmjRyEUF1OHHnMx-xCvUUimbd_auXDxH-k66vULm46he9xSs-oD00XaZzS3nF9H6yAXrF6_RTe3YZfKuK56TfbmvM9woXHeOrwZGm0mMP7mewgHD325vsNshlQvqaSTD';

  static const List<_TimelineStep> _steps = [
    _TimelineStep(label: 'Order Confirmed', isCompleted: true, hasConnector: true),
    _TimelineStep(label: 'Preparing', isCompleted: true, hasConnector: true),
    _TimelineStep(label: 'Out for Delivery', isCompleted: true, hasConnector: false),
    _TimelineStep(label: 'Delivered', isCompleted: false, hasConnector: false),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Track Order',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                    Text('Order #45782', style: AppTextStyles.cardTitle()),
                    const StatusPill(
                      label: 'On the way',
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSurface,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final step in _steps) _TimelineStepRow(step: step),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.fireSunGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const NetworkAvatar(
                  imageUrl: _courierImageUrl,
                  radius: 35,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Partner',
                        style: AppTextStyles.labelSm().copyWith(
                          color: Colors.white.withOpacityValue(0.8),
                        ),
                      ),
                      Text(
                        'Yusuf Adeyemi',
                        style: AppTextStyles.cardTitle().copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.white),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '4.9',
                            style: AppTextStyles.labelSm().copyWith(
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
          const SizedBox(height: AppSpacing.xl),
          OutlinedCard(
            backgroundColor: AppColors.surfaceContainer,
            borderRadius: 16,
            child: Column(
              children: [
                Text(
                  'Estimated Arrival',
                  style: AppTextStyles.labelSm().copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  '12 minutes',
                  style: AppTextStyles.h2().copyWith(
                    color: AppColors.primary,
                  ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: step.isCompleted
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: step.isCompleted
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (step.hasConnector)
                Container(
                  width: 2,
                  height: 40,
                  color: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Text(
            step.label,
            style: AppTextStyles.labelBold().copyWith(
              color: step.isCompleted
                  ? AppColors.onSurface
                  : AppColors.onSurfaceVariant,
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
