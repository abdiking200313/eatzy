import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/service_module.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Services',
      showBackButton: showBackButton,
      // A true one-column list rather than a fixed-aspect-ratio grid, so
      // each card sizes to its own content instead of overflowing at
      // narrow widths / large text scales.
      body: ListView.separated(
        padding: const EdgeInsets.all(TwSpacing.x5),
        itemCount:
            ServiceRegistry.modules.length + ServiceRegistry.comingSoon.length,
        separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x5),
        itemBuilder: (context, index) {
          if (index >= ServiceRegistry.modules.length) {
            return _ComingSoonCard(
              category: ServiceRegistry
                  .comingSoon[index - ServiceRegistry.modules.length],
            );
          }
          final module = ServiceRegistry.modules[index];
          // White card only ("one card per list") — the service accent is
          // confined to the 48px ServiceIconChip, never the card fill or
          // border.
          return OutlinedCard(
            child: InkWell(
              key: Key('services-${module.id.name}'),
              // `go`, not `push`: module.entryRoute belongs to its own shell
              // branch (see app_router.dart), so this switches branches
              // within the persistent bottom-nav shell instead of stacking a
              // full-screen route over it and hiding the nav bar (#67).
              onTap: () => context.go(module.entryRoute),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZivoServiceTheme(
                    serviceId: module.id,
                    child: ServiceIconChip(icon: module.icon, iconSize: 26),
                  ),
                  const SizedBox(height: TwSpacing.rhythmDefault),
                  Text(
                    module.title,
                    textAlign: TextAlign.center,
                    style: TwText.fontBoldBase,
                  ),
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Text(
                    module.description,
                    textAlign: TextAlign.center,
                    style: TwText.textSm,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A placeholder category with no service behind it yet: same card as a real
/// module, but tapping it only shows a "coming soon" snackbar.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.category});

  final ComingSoonCategory category;

  @override
  Widget build(BuildContext context) {
    const platform = ZivoServiceColors.platform;
    return OutlinedCard(
      child: InkWell(
        key: Key('services-coming-soon-${category.id}'),
        onTap: () =>
            showCartSnackBar(context, '${category.title} is coming soon'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ServiceIconChip(
              icon: category.icon,
              background: platform.soft,
              foreground: platform.accent,
              iconSize: 26,
            ),
            const SizedBox(height: TwSpacing.rhythmDefault),
            Text(
              category.title,
              textAlign: TextAlign.center,
              style: TwText.fontBoldBase,
            ),
            const SizedBox(height: TwSpacing.rhythmTight),
            Text(
              category.description,
              textAlign: TextAlign.center,
              style: TwText.textSm,
            ),
            const SizedBox(height: TwSpacing.rhythmTight),
            const StatusPill(label: 'Coming soon', fontSize: 11),
          ],
        ),
      ),
    );
  }
}
