import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/service_module.dart';
import '../config/theme.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Explore',
      showBackButton: false,
      body: ListView.separated(
        padding: const EdgeInsets.all(TwSpacing.x5),
        itemCount: ServiceRegistry.modules.length,
        separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x3),
        itemBuilder: (context, index) {
          final module = ServiceRegistry.modules[index];
          // White card only ("one card per list") — the service accent is
          // confined to the 48px ServiceIconChip, never the card fill or
          // border.
          return Card(
            color: TwColors.card,
            elevation: 0.6,
            shadowColor: TwColors.slate900.withOpacityValue(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TwRadius.xl),
              side: const BorderSide(color: TwColors.border),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(TwSpacing.x3),
              // `go`, not `push`: module.entryRoute belongs to its own shell
              // branch (see app_router.dart), so this switches branches
              // within the persistent bottom-nav shell instead of stacking a
              // full-screen route over it and hiding the nav bar (#67).
              onTap: () => context.go(module.entryRoute),
              leading: ZivoServiceTheme(
                serviceId: module.id,
                child: ServiceIconChip(icon: module.icon),
              ),
              title: Text(module.title, style: TwText.fontBoldBase()),
              subtitle: Text(module.description),
              trailing: const Icon(
                Icons.chevron_right,
                color: TwColors.textMuted,
              ),
            ),
          );
        },
      ),
    );
  }
}
