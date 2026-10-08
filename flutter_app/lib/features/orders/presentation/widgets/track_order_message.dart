import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

/// A centered icon/title/message empty or error state for
/// `TrackOrderScreen`, with an optional retry action.
class TrackOrderMessage extends StatelessWidget {
  const TrackOrderMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TwColors.textMuted, size: 48),
            const SizedBox(height: TwSpacing.x3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TwText.fontBoldBase,
            ),
            const SizedBox(height: TwSpacing.x2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TwText.textSm.copyWith(color: TwColors.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: TwSpacing.x4),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
