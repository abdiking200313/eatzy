import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A minimal, on-brand replacement for Flutter's default grey
/// `ErrorWidget` box, installed via `ErrorWidget.builder` in `main.dart`
/// (issue #40). Shown in place of whatever widget subtree failed to build;
/// it deliberately offers no restart/retry action since it has no way to
/// know what would fix the underlying error, only that something did.
///
/// Kept independent of `Theme.of(context)` and wrapped in its own
/// [Directionality]/[Material]: a build error can happen anywhere in the
/// tree, including above the app's own `Directionality` (from
/// `MaterialApp`), so this must not assume one is already in scope.
class ErrorFallbackView extends StatelessWidget {
  const ErrorFallbackView({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: TwColors.bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TwSpacing.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: TwColors.textMuted,
                  size: 40,
                ),
                const SizedBox(height: TwSpacing.x3),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TwText.fontBoldBase,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
