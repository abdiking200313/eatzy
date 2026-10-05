import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// One step in [TrackingCard]'s progress timeline.
class TimelineStep {
  const TimelineStep({
    required this.label,
    required this.isCompleted,
    required this.hasConnector,
  });

  final String label;
  final bool isCompleted;
  final bool hasConnector;
}

/// Renders a single [TimelineStep] in [TrackingCard]: a dot (filled/checked
/// when completed), a connecting line down to the next step, and the step's
/// label.
class TimelineStepRow extends StatelessWidget {
  const TimelineStepRow({super.key, required this.step});

  final TimelineStep step;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: TwSpacing.x5,
              height: TwSpacing.x5,
              decoration: BoxDecoration(
                color: step.isCompleted
                    ? palette.accent
                    : TwColors.borderStrong,
                borderRadius: BorderRadius.circular(TwRadius.full),
              ),
              child: step.isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (step.hasConnector)
              Container(
                width: 2,
                height: TwSpacing.x6,
                color: step.isCompleted
                    ? palette.accent
                    : TwColors.borderStrong,
              ),
          ],
        ),
        const SizedBox(width: TwSpacing.x4),
        Expanded(
          child: Text(
            step.label,
            style: TwText.fontBoldSm.copyWith(
              color: step.isCompleted ? TwColors.text : TwColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
