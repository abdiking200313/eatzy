import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../widgets/app_scaffold.dart';
import 'app_routes.dart';

/// Shown by [GoRouter]'s `errorBuilder` for an unrecognized path, replacing
/// go_router's default error page (issue #40). Gives the user a way back to
/// a known-good route instead of a dead end.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Page not found',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                color: TwColors.textMuted,
                size: 48,
              ),
              const SizedBox(height: TwSpacing.x3),
              Text(
                "We couldn't find that page",
                textAlign: TextAlign.center,
                style: TwText.fontBoldBase,
              ),
              const SizedBox(height: TwSpacing.x2),
              Text(
                "The link may be out of date, or the page may have moved.",
                textAlign: TextAlign.center,
                style: TwText.textSm.copyWith(color: TwColors.textMuted),
              ),
              const SizedBox(height: TwSpacing.x5),
              FilledButton(
                onPressed: () => context.go(AppRoutes.mainApp),
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
