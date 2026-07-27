import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../platform/localization/app_money.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/app_scaffold.dart';
import '../models/cleaning_models.dart';
import 'cleaning_controller.dart';

class CleaningHomeScreen extends StatelessWidget {
  const CleaningHomeScreen({super.key, this.controller, this.onChoose});

  final CleaningController? controller;
  final ValueChanged<CleaningProfessional>? onChoose;

  @override
  Widget build(BuildContext context) {
    final cleaningController = controller ?? CleaningController.instance;

    return AnimatedBuilder(
      animation: cleaningController,
      builder: (context, _) => AppScaffold(
        title: 'Cleaning',
        showBackButton: true,
        body:
            cleaningController.isLoading &&
                cleaningController.professionals.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : cleaningController.loadError != null &&
                  cleaningController.professionals.isEmpty
            ? _CleaningLoadError(
                message: cleaningController.loadError!,
                onRetry: cleaningController.load,
              )
            : ListView(
                padding: const EdgeInsets.all(TwSpacing.x5),
                children: [
                  Text('Choose your cleaner', style: TwText.text2xl()),
                  const SizedBox(height: TwSpacing.x2),
                  Text(
                    'Compare experience, specialties, languages, and '
                    'long-stay rates.',
                    style: TwText.textSm().copyWith(color: TwColors.textMuted),
                  ),
                  if (cleaningController.loadError case final error?) ...[
                    const SizedBox(height: TwSpacing.x4),
                    Text(
                      error,
                      style: TwText.textSm().copyWith(color: TwColors.error),
                    ),
                  ],
                  const SizedBox(height: TwSpacing.x6),
                  for (final cleaner in cleaningController.professionals) ...[
                    _CleanerCard(
                      cleaner: cleaner,
                      onChoose: () {
                        cleaningController.startNewBooking(cleaner);
                        final callback = onChoose;
                        if (callback != null) {
                          callback(cleaner);
                        } else {
                          context.push('/cleaning/book');
                        }
                      },
                    ),
                    const SizedBox(height: TwSpacing.x4),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CleaningLoadError extends StatelessWidget {
  const _CleaningLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: TwSpacing.x4),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _CleanerCard extends StatelessWidget {
  const _CleanerCard({required this.cleaner, required this.onChoose});

  final CleaningProfessional cleaner;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return OutlinedCard(
      backgroundColor: palette.card,
      borderColor: palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: palette.soft,
                foregroundColor: palette.accent,
                child: Text(cleaner.initials, style: TwText.fontBoldBase()),
              ),
              const SizedBox(width: TwSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cleaner.displayName, style: TwText.textXl()),
                    const SizedBox(height: TwSpacing.x1),
                    Text(
                      cleaner.headline,
                      style: TwText.textSm().copyWith(
                        color: TwColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: TwSpacing.x2),
                    Wrap(
                      spacing: TwSpacing.x3,
                      runSpacing: TwSpacing.x1,
                      children: [
                        _ProfileFact(
                          icon: Icons.star_rounded,
                          text:
                              '${cleaner.rating.toStringAsFixed(1)} '
                              '(${cleaner.reviewCount} reviews)',
                        ),
                        _ProfileFact(
                          icon: Icons.location_on_outlined,
                          text: cleaner.city,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TwSpacing.x4),
          Text(cleaner.bio, style: TwText.textSm()),
          const SizedBox(height: TwSpacing.x4),
          Wrap(
            spacing: TwSpacing.x2,
            runSpacing: TwSpacing.x2,
            children: [
              for (final specialty in cleaner.specialties)
                _SpecialtyChip(label: specialty.name),
            ],
          ),
          const SizedBox(height: TwSpacing.x4),
          Text(
            '${cleaner.experienceYears} years experience • '
            '${cleaner.languages.join(', ')}',
            style: TwText.textXs().copyWith(color: TwColors.textMuted),
          ),
          const SizedBox(height: TwSpacing.x5),
          _PriceAndAction(cleaner: cleaner, onChoose: onChoose),
        ],
      ),
    );
  }
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: context.serviceColors.accent),
        const SizedBox(width: TwSpacing.x1),
        Flexible(child: Text(text, style: TwText.textXs())),
      ],
    );
  }
}

class _PriceAndAction extends StatelessWidget {
  const _PriceAndAction({required this.cleaner, required this.onChoose});

  final CleaningProfessional cleaner;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final price = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'From',
          style: TwText.textXs().copyWith(color: TwColors.textMuted),
        ),
        Text(
          '${AppMoney.format(cleaner.startingWeeklyRate)}/week',
          style: TwText.fontBoldBase(),
        ),
      ],
    );
    final button = FilledButton(
      onPressed: onChoose,
      child: const Text('Choose cleaner'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              price,
              const SizedBox(height: TwSpacing.x3),
              button,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: price),
            const SizedBox(width: TwSpacing.x3),
            button,
          ],
        );
      },
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x3,
        vertical: TwSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(TwRadius.full),
      ),
      child: Text(
        label,
        style: TwText.textXs().copyWith(color: palette.accent),
      ),
    );
  }
}
